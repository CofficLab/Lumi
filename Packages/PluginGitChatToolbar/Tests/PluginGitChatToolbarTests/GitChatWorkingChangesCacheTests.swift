import Foundation
import Testing
import ProviderGit
@testable import PluginGitChatToolbar

/// 等待一次异步加载完成。
///
/// `refreshNow` 通过 Task 异步执行，InMemory provider 同步返回，
/// 100ms 内应能完成；如仍未完成则多等几轮。
private func waitForLoad() async {
    for _ in 0..<5 {
        await Task.yield()
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
}

/// 工作区变更项的缓存（见 issue #1300）。
///
/// 原先 `workingChanges` 是每次访问都重新合成并排序的计算属性，
/// 按钮的 label 与 tintColor 各读一次，弹层再读若干次 ——
/// 每次 body 求值要跑 O(N log N)，而 N 可达数千。
@MainActor
@Suite("GitChatToolbarViewModel 变更项缓存")
struct GitChatWorkingChangesCacheTests {

    private func makeStatus(
        modified: [String] = [],
        added: [String] = [],
        untracked: [String] = []
    ) -> GitStatus {
        GitStatus(
            branch: "main",
            remote: nil,
            modified: modified,
            added: added,
            untracked: untracked
        )
    }

    @Test("未加载时变更项为空")
    func emptyBeforeLoad() {
        let vm = GitChatToolbarViewModel(capability: nil)

        #expect(vm.workingChanges.isEmpty)
        #expect(vm.workingChangeCount == 0)
    }

    @Test("缓存的变更项与 status 合成结果一致")
    func cacheMatchesStatusSynthesis() async throws {
        let git = InMemoryGitRepositoryReading()
        git.addRepository(atPath: "/repo")
        git.setStatus(
            makeStatus(modified: ["a.swift"], added: ["b.swift"], untracked: ["new.txt"]),
            forPath: "/repo"
        )

        let capability = GitChatCapabilityAdapter(provider: git)
        let vm = GitChatToolbarViewModel(capability: capability)
        vm.updateProjectPath("/repo")

        try await waitForLoad()

        let expected = (try? await git.status(atPath: "/repo"))?.workingChanges() ?? []
        #expect(vm.workingChanges.map(\.path) == expected.map(\.path))
        #expect(vm.workingChangeCount == expected.count)
    }

    @Test("变更项按路径排序")
    func changesAreSortedByPath() async throws {
        let git = InMemoryGitRepositoryReading()
        git.addRepository(atPath: "/repo")
        git.setStatus(
            makeStatus(modified: ["z.swift"], added: ["a.swift"], untracked: ["m.txt"]),
            forPath: "/repo"
        )

        let capability = GitChatCapabilityAdapter(provider: git)
        let vm = GitChatToolbarViewModel(capability: capability)
        vm.updateProjectPath("/repo")

        try await waitForLoad()

        #expect(vm.workingChanges.map(\.path) == ["a.swift", "m.txt", "z.swift"])
    }

    @Test("项目切换后缓存被清空")
    func cacheClearedOnProjectSwitch() async throws {
        let git = InMemoryGitRepositoryReading()
        git.addRepository(atPath: "/repo")
        git.setStatus(makeStatus(modified: ["a.swift"]), forPath: "/repo")

        let capability = GitChatCapabilityAdapter(provider: git)
        let vm = GitChatToolbarViewModel(capability: capability)
        vm.updateProjectPath("/repo")
        try await waitForLoad()
        #expect(vm.workingChangeCount == 1)

        // 切到非 Git 项目：缓存必须清空，不能残留上一个仓库的数据。
        vm.updateProjectPath("/tmp/plain")
        try await waitForLoad()

        #expect(vm.workingChanges.isEmpty)
        #expect(vm.workingChangeCount == 0)
    }

    @Test("watch 停止后缓存被清空")
    func cacheClearedWhenWatchMissing() async throws {
        let git = InMemoryGitRepositoryReading()
        git.addRepository(atPath: "/repo")
        git.setStatus(makeStatus(modified: ["a.swift"]), forPath: "/repo")

        let capability = GitChatCapabilityAdapter(provider: git)
        let vm = GitChatToolbarViewModel(capability: capability)
        vm.updateProjectPath("/repo")
        try await waitForLoad()
        #expect(vm.workingChangeCount == 1)

        vm.resetForMissingWatch()

        #expect(vm.workingChanges.isEmpty)
        #expect(vm.workingChangeCount == 0)
    }
}
