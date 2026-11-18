import Foundation
import ProviderGit
import Testing
@testable import PluginGitChatToolbar

/// 门闩：让 Git 读取挂起，直到测试显式放行，用于确定性控制「请求在途时
/// 项目被关闭」的时序（#385）。
private actor CallGate {
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var released = false
    private(set) var enteredCount = 0

    func enter() async {
        enteredCount += 1
        if released { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func releaseAll() {
        released = true
        for waiter in waiters {
            waiter.resume()
        }
        waiters.removeAll()
    }
}

/// 把底层 InMemory 读取的所有调用都先卡在门闩上的装饰器。
private final class GatedGitRepositoryReading: GitRepositoryReading, @unchecked Sendable {
    private let gate: CallGate
    private let underlying: InMemoryGitRepositoryReading

    init(gate: CallGate, underlying: InMemoryGitRepositoryReading) {
        self.gate = gate
        self.underlying = underlying
    }

    func status(atPath path: String?) async throws -> GitStatus {
        await gate.enter()
        return try await underlying.status(atPath: path)
    }

    func log(atPath path: String?, count: Int, branch: String?, file: String?) async throws -> [GitCommitLog] {
        await gate.enter()
        return try await underlying.log(atPath: path, count: count, branch: branch, file: file)
    }

    func log(atPath path: String?, count: Int, skip: Int) async throws -> [GitCommitLog] {
        await gate.enter()
        return try await underlying.log(atPath: path, count: count, skip: skip)
    }

    func isRepository(atPath path: String?) async -> Bool {
        await gate.enter()
        return await underlying.isRepository(atPath: path)
    }

    func commitChanges(atPath path: String?, hash: String) async throws -> [GitCommitChange] {
        await gate.enter()
        return try await underlying.commitChanges(atPath: path, hash: hash)
    }

    func remoteURL(atPath path: String?, remote: String) async -> String? {
        await gate.enter()
        return await underlying.remoteURL(atPath: path, remote: remote)
    }
}

/// 回归覆盖 issue #385：关闭项目（`updateProjectPath(nil)`）与 watch 停止
/// （`resetForMissingWatch`）此前只清 UI、不作废在途刷新。旧仓库的请求
/// 返回时 generation 仍匹配，写回 `isGitRepository/status/commits`，Git
/// 按钮在无项目时复活。
@MainActor
@Suite(.serialized)
struct GitChatToolbarLateWriteBackTests {

    private func makeGatedStub() -> (GatedGitRepositoryReading, CallGate) {
        let git = InMemoryGitRepositoryReading()
        git.addRepository(atPath: "/repo")
        git.setStatus(GitStatus(branch: "main"), forPath: "/repo")
        git.setCommits([
            GitCommitLog(hash: "abc", author: "n", email: "e", date: "2026-09-16T00:00:00Z", message: "m"),
        ], forPath: "/repo")
        let gate = CallGate()
        return (GatedGitRepositoryReading(gate: gate, underlying: git), gate)
    }

    /// 带超时上限：capability 被提前释放等异常场景下快速失败，不挂死测试进程。
    @MainActor
    private func waitUntilEntered(_ gate: CallGate, atLeast count: Int) async {
        let deadline = Date().addingTimeInterval(10)
        while await gate.enteredCount < count, Date() < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    @Test("关闭项目后旧仓库的迟到结果不得写回")
    func closingProjectDiscardsInFlightResults() async throws {
        let (provider, gate) = makeGatedStub()
        // capability 由 ViewModel 弱持有，必须在测试侧保强引用，否则立即
        // 释放、performReload 直接早退，门闩永远等不到 3 次进入。
        let adapter = GitChatCapabilityAdapter(provider: provider)
        let vm = GitChatToolbarViewModel(capability: adapter)

        vm.updateProjectPath("/repo")
        await waitUntilEntered(gate, atLeast: 3)
        #expect(await gate.enteredCount >= 3)

        vm.updateProjectPath(nil)
        #expect(vm.isGitRepository == false)
        #expect(vm.status == nil)
        #expect(vm.commits.isEmpty)

        await gate.releaseAll()
        // 给迟到的 performReload 结果一点时间（若写回则立即出现）。
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(vm.isGitRepository == false)
        #expect(vm.status == nil)
        #expect(vm.commits.isEmpty)
    }

    @Test("watch 停止后旧仓库的迟到结果不得写回")
    func missingWatchDiscardsInFlightResults() async throws {
        let (provider, gate) = makeGatedStub()
        let adapter = GitChatCapabilityAdapter(provider: provider)
        let vm = GitChatToolbarViewModel(capability: adapter)

        vm.updateProjectPath("/repo")
        await waitUntilEntered(gate, atLeast: 3)
        #expect(await gate.enteredCount >= 3)

        vm.resetForMissingWatch()
        #expect(vm.status == nil)
        #expect(vm.commits.isEmpty)

        await gate.releaseAll()
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(vm.isGitRepository == false)
        #expect(vm.status == nil)
        #expect(vm.commits.isEmpty)
    }
}
