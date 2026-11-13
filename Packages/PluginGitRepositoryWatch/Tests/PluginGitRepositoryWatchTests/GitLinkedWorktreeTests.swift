import Foundation
import ProviderGitRepositoryWatch
import Testing
@testable import PluginGitRepositoryWatch

// MARK: - 测试夹具

/// 模拟 `git worktree add` 生成的 linked worktree 布局：
/// - common dir：`main/.git`，存放分支 ref / packed-refs / 共享 refs。
/// - private dir：`main/.git/worktrees/linked`，存放 HEAD / index / commondir。
/// - 工作区项目目录 `linked/` 的 `.git` 是指向 private dir 的指针文件。
private struct LinkedWorktreeFixture {
    let commonDir: URL
    let privateDir: URL
    let projectURL: URL

    static func make(label: String) throws -> LinkedWorktreeFixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginGitRepositoryWatchTests-linked-\(label)-\(UUID().uuidString)", isDirectory: true)
        let commonDir = root.appendingPathComponent("main/.git", isDirectory: true)
        let privateDir = commonDir.appendingPathComponent("worktrees/linked", isDirectory: true)
        let projectURL = root.appendingPathComponent("linked", isDirectory: true)
        try FileManager.default.createDirectory(at: privateDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        try "gitdir: \(privateDir.path)\n".write(
            to: projectURL.appendingPathComponent(".git"), atomically: true, encoding: .utf8
        )
        // commondir 是相对 private dir 的路径：worktrees/linked/../.. == main/.git。
        try "../..\n".write(
            to: privateDir.appendingPathComponent("commondir"), atomically: true, encoding: .utf8
        )
        return LinkedWorktreeFixture(commonDir: commonDir, privateDir: privateDir, projectURL: projectURL)
    }

    func writeCommon(_ relativePath: String, _ contents: String) throws {
        let target = commonDir.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: target, atomically: true, encoding: .utf8)
    }

    func writePrivate(_ relativePath: String, _ contents: String) throws {
        let target = privateDir.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: target, atomically: true, encoding: .utf8)
    }
}

// MARK: - Linked worktree 快照与监听（回归 #156）

/// 回归 #156：linked worktree 的分支 ref / packed-refs / 共享 refs 都在 common dir，
/// 旧实现只读 worktree-private 目录、从不解析 `commondir`，导致 HEAD 恒为 nil、
/// refs 指纹恒为 nil，提交与切换分支都无法触发 headChanged / refsChanged。
@Suite("Linked worktree")
@MainActor
struct GitLinkedWorktreeTests {

    @Test("linked worktree 的 HEAD 从 common dir 解析分支 hash（回归 #156）")
    func headResolvesFromCommonDir() throws {
        let fx = try LinkedWorktreeFixture.make(label: "head")
        try fx.writePrivate("HEAD", "ref: refs/heads/feature\n")
        try fx.writeCommon("refs/heads/feature", "abc123\n")

        let snapshot = GitDirectoryResolver.readSnapshot(gitDirectory: fx.privateDir)

        #expect(snapshot.head == "abc123", "分支 ref 在 common dir，HEAD 不应为 nil")
        #expect(snapshot.headRef == "refs/heads/feature")
    }

    @Test("linked worktree 提交后 HEAD hash 变化（回归 #156）")
    func commitInCommonDirChangesHead() throws {
        let fx = try LinkedWorktreeFixture.make(label: "commit")
        try fx.writePrivate("HEAD", "ref: refs/heads/feature\n")
        try fx.writeCommon("refs/heads/feature", "abc123\n")
        let before = GitDirectoryResolver.readSnapshot(gitDirectory: fx.privateDir)

        try fx.writeCommon("refs/heads/feature", "def456\n")
        let after = GitDirectoryResolver.readSnapshot(gitDirectory: fx.privateDir)

        #expect(before.head == "abc123")
        #expect(after.head == "def456")
        #expect(before != after, "提交后快照必须不同，否则 headChanged 不触发")
    }

    @Test("linked worktree 的 refs 指纹跟踪 common dir（回归 #156）")
    func refsFingerprintTracksCommonRefs() throws {
        let fx = try LinkedWorktreeFixture.make(label: "refs")
        try fx.writePrivate("HEAD", "ref: refs/heads/feature\n")
        try fx.writeCommon("refs/heads/feature", "abc123\n")
        let before = GitDirectoryResolver.readSnapshot(gitDirectory: fx.privateDir)

        try fx.writeCommon("refs/heads/other", "abc123\n")
        let after = GitDirectoryResolver.readSnapshot(gitDirectory: fx.privateDir)

        #expect(before.refs != nil, "common dir 的分支应计入 refs 指纹")
        #expect(before.refs != after.refs, "common dir 新增分支后 refs 指纹必须变化")
    }

    @Test("linked worktree 的 stash 从 common dir 读取（回归 #156）")
    func stashResolvesFromCommonDir() throws {
        let fx = try LinkedWorktreeFixture.make(label: "stash")
        try fx.writePrivate("HEAD", "ref: refs/heads/feature\n")
        try fx.writeCommon("refs/stash", "stashhash\n")

        let snapshot = GitDirectoryResolver.readSnapshot(gitDirectory: fx.privateDir)

        #expect(snapshot.stash != nil, "refs/stash 在 common dir，不应为 nil")
    }

    @Test("linked worktree 提交触发 headChanged（回归 #156）")
    func commitBroadcastsHeadChanged() async throws {
        let fx = try LinkedWorktreeFixture.make(label: "provider")
        try fx.writePrivate("HEAD", "ref: refs/heads/feature\n")
        try fx.writePrivate("index", "initial-index")
        try fx.writeCommon("refs/heads/feature", "abc123\n")

        let provider = GitRepositoryWatchProvider()
        var events: [GitRepositoryWatchingEvent] = []
        let handle = provider.addObserver { events.append($0) }
        defer {
            handle.cancel()
            provider.stopWatching()
        }

        provider.startWatching(repositoryURL: fx.projectURL)
        #expect(provider.isWatcherActive)
        try await Task.sleep(for: .milliseconds(100))

        // 模拟 worktree 内提交：common dir 分支前进 + private dir index 改写（触发 FSEvents）。
        try fx.writeCommon("refs/heads/feature", "def456\n")
        try fx.writePrivate("index", "updated-index")

        let sawHeadChange = await waitUntil(timeout: 5) {
            events.contains {
                if case .headChanged = $0 { return true }
                return false
            }
        }

        #expect(sawHeadChange, "linked worktree 提交后没有 headChanged，工具栏停在旧 commit")
    }

    @Test("普通仓库没有 commondir，common dir 即自身")
    func normalRepoCommonDirIsSelf() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginGitRepositoryWatchTests-normal-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let common = GitDirectoryResolver.commonDirectory(gitDirectory: root)

        #expect(common.standardizedFileURL == root.standardizedFileURL)
    }

    @Test("相对 commondir 相对 private dir 解析")
    func relativeCommonDirResolves() throws {
        let fx = try LinkedWorktreeFixture.make(label: "commondir-relative")

        let common = GitDirectoryResolver.commonDirectory(gitDirectory: fx.privateDir)

        #expect(common.standardizedFileURL == fx.commonDir.standardizedFileURL)
    }

    @Test("绝对 commondir 原样解析")
    func absoluteCommonDirResolves() throws {
        let fx = try LinkedWorktreeFixture.make(label: "commondir-absolute")
        try fx.writePrivate("commondir", "\(fx.commonDir.path)\n")

        let common = GitDirectoryResolver.commonDirectory(gitDirectory: fx.privateDir)

        #expect(common.standardizedFileURL == fx.commonDir.standardizedFileURL)
    }

    /// 轮询等待条件成立，避免依赖固定 sleep 时长。
    private func waitUntil(
        timeout: TimeInterval,
        poll: TimeInterval = 0.1,
        _ condition: @MainActor () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: UInt64(poll * 1_000_000_000))
        }
        return condition()
    }
}
