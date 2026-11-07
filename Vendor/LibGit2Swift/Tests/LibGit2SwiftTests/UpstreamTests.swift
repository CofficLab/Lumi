import Clibgit2
import Foundation
import XCTest
@testable import LibGit2Swift

/// 覆盖 upstream 解析、HEAD 语义与拉取安全性。
///
/// 这些用例保护的是"pull/push 可能操作错误分支"这一历史缺陷的回归。
final class UpstreamTests: XCTestCase {
    private var root: URL!

    override func setUp() async throws {
        try await super.setUp()
        LibGit2.initialize()
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibGit2SwiftUpstreamTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
        LibGit2.shutdown()
        try await super.tearDown()
    }

    // MARK: - HEAD 语义

    func testCurrentBranchNameReturnsNilWhenDetached() throws {
        let repo = try makeRepository(named: "detached")
        try commit(in: repo, file: "a.txt", content: "a", message: "first")
        try commit(in: repo, file: "b.txt", content: "b", message: "second")

        // 正常状态返回分支名。
        XCTAssertEqual(try LibGit2.currentBranchName(at: repo.path), "main")

        // detached 后必须返回 nil，而不是 commit SHA（历史缺陷）。
        try runGit(["checkout", "--detach", "HEAD~1"], in: repo)
        XCTAssertNil(try LibGit2.currentBranchName(at: repo.path))
        XCTAssertTrue(try LibGit2.isHeadDetached(at: repo.path))

        // detached 状态下 headCommitHash 仍应可用。
        XCTAssertNotNil(try LibGit2.headCommitHash(at: repo.path))
    }

    func testHeadCommitHashReturnsNilForUnbornHead() throws {
        let repo = try makeRepository(named: "unborn")
        XCTAssertNil(try LibGit2.headCommitHash(at: repo.path))
        XCTAssertNil(try LibGit2.currentBranchName(at: repo.path))
    }

    // MARK: - Upstream 解析

    func testUpstreamBindingResolvesConfiguredRemoteAndBranch() throws {
        let (_, local) = try makeLocalWithUpstream(named: "binding")
        let binding = try XCTUnwrap(try LibGit2.upstreamBinding(at: local.path))

        XCTAssertEqual(binding.localBranch, "main")
        XCTAssertEqual(binding.localReference, "refs/heads/main")
        XCTAssertEqual(binding.remote, "origin")
        XCTAssertEqual(binding.remoteBranch, "main")
        XCTAssertEqual(binding.remoteTrackingReference, "refs/remotes/origin/main")
    }

    /// 关键回归：本地分支名与远程分支名不同时，必须按 upstream 解析，
    /// 而不是假定二者同名。
    func testUpstreamBindingHonorsDivergentRemoteBranchName() throws {
        let remote = try makeBareRemote(named: "divergent")
        let local = try makeRepository(named: "divergent-local")
        try commit(in: local, file: "a.txt", content: "a", message: "first")
        try runGit(["remote", "add", "origin", remote.path], in: local)
        // 本地分支叫 main，但 upstream 指向远程的 release 分支。
        try runGit(["push", "origin", "main:release"], in: local)
        try runGit(["config", "branch.main.remote", "origin"], in: local)
        try runGit(["config", "branch.main.merge", "refs/heads/release"], in: local)

        let binding = try XCTUnwrap(try LibGit2.upstreamBinding(at: local.path))
        XCTAssertEqual(binding.remoteBranch, "release")
        XCTAssertEqual(binding.remoteTrackingReference, "refs/remotes/origin/release")
        // fetch 必须从**远程**的 release 拉取，而不是本地的 main。
        XCTAssertEqual(
            binding.fetchRefspec,
            "refs/heads/release:refs/remotes/origin/release"
        )
        // push 必须推到远程的 release，而不是远程的 main。
        XCTAssertEqual(
            binding.pushRefspec,
            "refs/heads/main:refs/heads/release"
        )
    }

    func testUpstreamBindingIsNilWithoutConfiguration() throws {
        let repo = try makeRepository(named: "no-upstream")
        try commit(in: repo, file: "a.txt", content: "a", message: "first")
        XCTAssertNil(try LibGit2.upstreamBinding(at: repo.path))
    }

    func testUpstreamBindingIsNilForDetachedHead() throws {
        let (_, local) = try makeLocalWithUpstream(named: "detached-upstream")
        try runGit(["checkout", "--detach", "HEAD"], in: local)
        XCTAssertNil(try LibGit2.upstreamBinding(at: local.path))
    }

    // MARK: - pull / push 的 upstream 感知与安全性

    func testPushWithoutUpstreamThrows() throws {
        let repo = try makeRepository(named: "push-no-upstream")
        try commit(in: repo, file: "a.txt", content: "a", message: "first")

        XCTAssertThrowsError(try LibGit2.push(at: repo.path, verbose: false)) { error in
            guard case LibGit2Error.noUpstreamConfigured = error else {
                return XCTFail("expected noUpstreamConfigured, got \(error)")
            }
        }
    }

    func testPullWithoutUpstreamThrows() throws {
        let repo = try makeRepository(named: "pull-no-upstream")
        try commit(in: repo, file: "a.txt", content: "a", message: "first")

        XCTAssertThrowsError(try LibGit2.pull(at: repo.path, verbose: false)) { error in
            guard case LibGit2Error.noUpstreamConfigured = error else {
                return XCTFail("expected noUpstreamConfigured, got \(error)")
            }
        }
    }

    /// 未设置 upstream 时，即便存在名为 origin 的远程也必须报错，
    /// 不能退回"远程分支名 == 本地分支名"的猜测。
    func testPullWithRemoteButNoUpstreamThrows() throws {
        let remote = try makeBareRemote(named: "remote-only")
        let local = try makeRepository(named: "remote-only-local")
        try commit(in: local, file: "a.txt", content: "a", message: "first")
        try runGit(["remote", "add", "origin", remote.path], in: local)

        XCTAssertThrowsError(try LibGit2.pull(at: local.path, verbose: false)) { error in
            guard case LibGit2Error.noUpstreamConfigured = error else {
                return XCTFail("expected noUpstreamConfigured, got \(error)")
            }
        }
    }

    func testPullFastForwardOnlyRejectsDivergence() throws {
        let (remote, local) = try makeLocalWithUpstream(named: "ff-only")

        // 远程新增提交
        let pusher = try cloneInto(named: "ff-only-pusher", remote: remote)
        try commit(in: pusher, file: "remote.txt", content: "remote", message: "remote change")
        try runGit(["push", "origin", "main"], in: pusher)

        // 本地也新增提交，造成分叉
        try commit(in: local, file: "local.txt", content: "local", message: "local change")

        // 已 fetch 到远程引用，但无法快进
        try LibGit2.fetch(at: local.path, verbose: false)
        XCTAssertThrowsError(
            try LibGit2.pull(at: local.path, strategy: .fastForwardOnly, verbose: false)
        ) { error in
            guard case LibGit2Error.pullFailed = error else {
                return XCTFail("expected pullFailed, got \(error)")
            }
        }
    }

    func testPullMergeStrategyCreatesMergeCommitOnDivergence() throws {
        let (remote, local) = try makeLocalWithUpstream(named: "merge-diverge")

        let pusher = try cloneInto(named: "merge-diverge-pusher", remote: remote)
        try commit(in: pusher, file: "remote.txt", content: "remote", message: "remote change")
        try runGit(["push", "origin", "main"], in: pusher)

        try commit(in: local, file: "local.txt", content: "local", message: "local change")

        try LibGit2.pull(at: local.path, strategy: .merge, verbose: false)

        // 合并后应产生一个合并提交（存在 MERGE_HEAD 的历史），且工作区干净。
        let parents = try runGit(["rev-list", "--parents", "-n", "1", "HEAD"], in: local)
            .split(separator: " ")
        XCTAssertEqual(parents.count, 3, "merge commit should have two parents")

        // 两侧文件都应存在。
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: local.appendingPathComponent("local.txt").path
        ))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: local.appendingPathComponent("remote.txt").path
        ))
        XCTAssertFalse(try LibGit2.hasUncommittedChanges(at: local.path, verbose: false))
    }

    func testPullRebaseStrategyRebasesLocalCommitsOntoUpstream() throws {
        let (remote, local) = try makeLocalWithUpstream(named: "rebase-diverge")

        let pusher = try cloneInto(named: "rebase-diverge-pusher", remote: remote)
        try commit(in: pusher, file: "remote.txt", content: "remote", message: "remote change")
        try runGit(["push", "origin", "main"], in: pusher)

        try commit(in: local, file: "local.txt", content: "local", message: "local change")

        try LibGit2.pull(at: local.path, strategy: .rebase, verbose: false)

        let parents = try runGit(["rev-list", "--parents", "-n", "1", "HEAD"], in: local)
            .split(separator: " ")
        XCTAssertEqual(parents.count, 2, "rebased commit should have one parent")
        XCTAssertEqual(
            try runGit(["show", "-s", "--format=%s", "HEAD"], in: local).trimmingCharacters(in: .whitespacesAndNewlines),
            "local change"
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: local.appendingPathComponent("local.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: local.appendingPathComponent("remote.txt").path))
        XCTAssertFalse(try LibGit2.hasUncommittedChanges(at: local.path, verbose: false))
    }

    /// 关键安全回归：快进时若存在会冲突的本地改动，必须拒绝并保留用户改动，
    /// 而不是像历史实现那样使用 GIT_CHECKOUT_FORCE 覆盖。
    func testPullFastForwardPreservesConflictingLocalChanges() throws {
        let (remote, local) = try makeLocalWithUpstream(named: "preserve-local")

        let pusher = try cloneInto(named: "preserve-local-pusher", remote: remote)
        try commit(in: pusher, file: "README.md", content: "v2", message: "remote update")
        try runGit(["push", "origin", "main"], in: pusher)

        // 本地修改同一个文件（未提交）
        let readme = local.appendingPathComponent("README.md")
        try "local edit".write(to: readme, atomically: true, encoding: .utf8)
        let headBefore = try runGit(["rev-parse", "HEAD"], in: local)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        XCTAssertThrowsError(try LibGit2.pull(at: local.path, verbose: false))

        XCTAssertEqual(
            try String(contentsOf: readme, encoding: .utf8),
            "local edit",
            "local edits must be preserved"
        )
        let headAfter = try runGit(["rev-parse", "HEAD"], in: local)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(headAfter, headBefore, "branch must not move when checkout is blocked")
    }

    /// upstream 指向的远程分支不存在时，必须给出明确错误，而不是静默"已是最新"。
    func testPullReportsUpstreamReferenceNotFound() throws {
        let (_, local) = try makeLocalWithUpstream(named: "missing-tracking")

        // 把 upstream 指向一个远程不存在的分支：fetch 不会报错（无匹配 ref），
        // 但远程跟踪引用创建不出来，pull 必须明确报告。
        try runGit(["config", "branch.main.merge", "refs/heads/does-not-exist"], in: local)

        XCTAssertThrowsError(try LibGit2.pull(at: local.path, verbose: false)) { error in
            guard case LibGit2Error.upstreamReferenceNotFound = error else {
                return XCTFail("expected upstreamReferenceNotFound, got \(error)")
            }
        }
    }

    // MARK: - 队列池

    func testQueuePoolNormalizesEquivalentPaths() {
        let a = LibGit2QueuePool.normalize("/tmp/foo/bar")
        let b = LibGit2QueuePool.normalize("/tmp/foo/./bar")
        let c = LibGit2QueuePool.normalize("/tmp/foo/baz/../bar")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a, c)
    }

    func testQueuePoolExecutesSameRepositorySerially() {
        let pool = LibGit2QueuePool.shared
        let path = "/tmp/queue-serial-\(UUID().uuidString)"

        var order: [Int] = []
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: 20) { index in
            pool.sync(repositoryPath: path) {
                lock.lock()
                order.append(index)
                lock.unlock()
            }
        }
        XCTAssertEqual(order.count, 20)
    }

    func testQueuePoolAllowsDistinctRepositoriesInParallel() {
        let pool = LibGit2QueuePool.shared
        let gate = DispatchSemaphore(value: 0)
        let entered = DispatchSemaphore(value: 0)

        // 仓库 A 持锁等待；仓库 B 必须能同时进入，证明不同仓库不互相阻塞。
        DispatchQueue.global().async {
            pool.sync(repositoryPath: "/tmp/queue-parallel-a") {
                entered.signal()
                _ = gate.wait(timeout: .now() + 5)
            }
        }
        entered.wait()

        var reachedB = false
        DispatchQueue.global().async {
            pool.sync(repositoryPath: "/tmp/queue-parallel-b") {
                reachedB = true
            }
        }

        let deadline = Date().addingTimeInterval(3)
        while !reachedB, Date() < deadline {
            usleep(10_000)
        }
        gate.signal()
        XCTAssertTrue(reachedB, "a slow repository must not block other repositories")
    }

    func testQueuePoolSupportsReentrancy() {
        let pool = LibGit2QueuePool.shared
        let path = "/tmp/queue-reentrant-\(UUID().uuidString)"
        // 重入不应死锁（历史实现依赖 same-queue 检测避免死锁）。
        let value = pool.sync(repositoryPath: path) {
            pool.sync(repositoryPath: path) { 42 }
        }
        XCTAssertEqual(value, 42)
    }

    // MARK: - 测试脚手架

    private func makeRepository(named name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try runGit(["init", "--initial-branch=main", url.path], in: root)
        try runGit(["config", "user.name", "Test User"], in: url)
        try runGit(["config", "user.email", "test@example.com"], in: url)
        return url
    }

    private func makeBareRemote(named name: String) throws -> URL {
        let url = root.appendingPathComponent("\(name).git")
        try runGit(["init", "--bare", url.path], in: root)
        return url
    }

    @discardableResult
    private func commit(in repo: URL, file: String, content: String, message: String) throws -> String {
        try content.write(
            to: repo.appendingPathComponent(file),
            atomically: true,
            encoding: .utf8
        )
        try runGit(["add", file], in: repo)
        try runGit(["commit", "-m", message], in: repo)
        return try runGit(["rev-parse", "HEAD"], in: repo)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 建立 bare remote + 已配置 upstream 的本地克隆。
    private func makeLocalWithUpstream(named name: String) throws -> (remote: URL, local: URL) {
        let remote = try makeBareRemote(named: name)
        let seed = try makeRepository(named: "\(name)-seed")
        try commit(in: seed, file: "README.md", content: "v1", message: "Initial commit")
        try runGit(["remote", "add", "origin", remote.path], in: seed)
        try runGit(["push", "-u", "origin", "main"], in: seed)

        let local = try cloneInto(named: "\(name)-local", remote: remote)
        return (remote, local)
    }

    private func cloneInto(named name: String, remote: URL) throws -> URL {
        let url = root.appendingPathComponent(name)
        try runGit(["clone", remote.path, url.path], in: root)
        try runGit(["config", "user.name", "Test User"], in: url)
        try runGit(["config", "user.email", "test@example.com"], in: url)
        return url
    }

    @discardableResult
    private func runGit(_ arguments: [String], in directory: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = directory

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        try process.run()
        process.waitUntilExit()

        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = error.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "UpstreamTests.git",
                code: Int(process.terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey: String(data: errorData, encoding: .utf8) ?? "git failed",
                ]
            )
        }
        return String(data: outputData, encoding: .utf8) ?? ""
    }
}
