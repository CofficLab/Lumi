import Foundation
import ProviderGitRepositoryWatch
import Testing
@testable import PluginGitRepositoryWatch

// MARK: - 测试夹具

/// 在临时目录里搭建一个最小的 Git 仓库骨架。
private struct GitFixture {
    let projectURL: URL
    let gitDirectory: URL

    /// 创建一个只含 `.git` 目录的临时项目。
    static func makeProject(label: String) throws -> GitFixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginGitRepositoryWatchTests-\(label)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let git = root.appendingPathComponent(".git", isDirectory: true)
        try FileManager.default.createDirectory(at: git, withIntermediateDirectories: true)
        return GitFixture(projectURL: root, gitDirectory: git)
    }

    /// 在 `.git` 下写入相对路径文件。
    func writeGitFile(_ relativePath: String, contents: String) throws {
        let target = gitDirectory.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: target.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: target, atomically: true, encoding: .utf8)
    }

    /// 把 `.git` 替换成一个 gitdir 指针文件。
    func replaceGitDirectoryWithPointer(_ contents: String) throws {
        let dotGit = projectURL.appendingPathComponent(".git")
        try FileManager.default.removeItem(at: dotGit)
        try contents.write(to: dotGit, atomically: true, encoding: .utf8)
    }
}

// MARK: - Git 目录解析

@Suite("Git 目录解析")
struct GitDirectoryResolverTests {

    @Test(".git 是目录时直接返回该目录")
    func resolvesGitDirectory() throws {
        let fixture = try GitFixture.makeProject(label: "dir")

        let resolved = try GitDirectoryResolver.resolveGitDirectory(for: fixture.projectURL)

        #expect(resolved.standardizedFileURL == fixture.gitDirectory.standardizedFileURL)
    }

    @Test(".git 指向绝对路径时原样返回")
    func resolvesAbsoluteGitFile() throws {
        let fixture = try GitFixture.makeProject(label: "absolute")
        let target = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginGitRepositoryWatchTests-target-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try fixture.replaceGitDirectoryWithPointer("gitdir: \(target.path)\n")

        let resolved = try GitDirectoryResolver.resolveGitDirectory(for: fixture.projectURL)

        #expect(resolved.path == target.path)
    }

    @Test(".git 指向相对路径时相对项目目录解析")
    func resolvesRelativeGitFile() throws {
        let fixture = try GitFixture.makeProject(label: "relative")
        let nested = fixture.projectURL.appendingPathComponent("nested/git", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try fixture.replaceGitDirectoryWithPointer("gitdir: nested/git\n")

        let resolved = try GitDirectoryResolver.resolveGitDirectory(for: fixture.projectURL)

        #expect(resolved.standardizedFileURL == nested.standardizedFileURL)
    }

    @Test(".git 文件多行时取含 gitdir: 的那一行")
    func picksGitDirLineFromMultiLineFile() throws {
        let fixture = try GitFixture.makeProject(label: "multiline")
        let target = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginGitRepositoryWatchTests-target-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try fixture.replaceGitDirectoryWithPointer("some header\ngitdir: \(target.path)\n")

        let resolved = try GitDirectoryResolver.resolveGitDirectory(for: fixture.projectURL)

        #expect(resolved.path == target.path)
    }

    @Test("项目目录是仓库子目录时向上找到仓库根的 .git（回归 #913）")
    func resolvesAncestorGitDirectory() throws {
        let fixture = try GitFixture.makeProject(label: "ancestor")
        let nested = fixture.projectURL.appendingPathComponent("Sources/Feature", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        let resolved = try GitDirectoryResolver.resolveGitDirectory(for: nested)

        #expect(resolved.standardizedFileURL == fixture.gitDirectory.standardizedFileURL)
    }

    @Test(".git 不存在时抛出未找到错误")
    func throwsWhenGitDirectoryMissing() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginGitRepositoryWatchTests-missing-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        #expect(throws: GitDirectoryResolver.ResolverError.self) {
            try GitDirectoryResolver.resolveGitDirectory(for: root)
        }
    }

    @Test(".git 文件缺少 gitdir: 行时抛出非法文件错误")
    func throwsWhenGitFileInvalid() throws {
        let fixture = try GitFixture.makeProject(label: "invalid")
        try fixture.replaceGitDirectoryWithPointer("this is not a gitdir pointer\n")

        #expect(throws: GitDirectoryResolver.ResolverError.self) {
            try GitDirectoryResolver.resolveGitDirectory(for: fixture.projectURL)
        }
    }
}

// MARK: - Git 目录快照

@Suite("Git 目录快照")
struct GitDirectorySnapshotTests {

    @Test("HEAD 是直接 hash 时返回该 hash")
    func readsDirectHeadHash() throws {
        let fixture = try GitFixture.makeProject(label: "head-hash")
        try fixture.writeGitFile("HEAD", contents: "abc123\n")

        let head = GitDirectoryResolver.readHeadHash(gitDirectory: fixture.gitDirectory)

        #expect(head == "abc123")
    }

    @Test("HEAD 指向 ref 时读取对应 ref 文件")
    func readsHeadRef() throws {
        let fixture = try GitFixture.makeProject(label: "head-ref")
        try fixture.writeGitFile("HEAD", contents: "ref: refs/heads/main\n")
        try fixture.writeGitFile("refs/heads/main", contents: "deadbeef\n")

        let head = GitDirectoryResolver.readHeadHash(gitDirectory: fixture.gitDirectory)

        #expect(head == "deadbeef")
    }

    @Test("ref 文件缺失时回退到 packed-refs")
    func fallsBackToPackedRefs() throws {
        let fixture = try GitFixture.makeProject(label: "packed-refs")
        try fixture.writeGitFile("HEAD", contents: "ref: refs/heads/main\n")
        try fixture.writeGitFile("packed-refs", contents: "# pack-refs with: peeled\ncafe0000 refs/heads/main\n")

        let head = GitDirectoryResolver.readHeadHash(gitDirectory: fixture.gitDirectory)

        #expect(head == "cafe0000")
    }

    @Test("packed-refs 中也没有该 ref 时返回 nil")
    func returnsNilWhenRefMissingEverywhere() throws {
        let fixture = try GitFixture.makeProject(label: "missing-ref")
        try fixture.writeGitFile("HEAD", contents: "ref: refs/heads/main\n")
        try fixture.writeGitFile("packed-refs", contents: "cafe0000 refs/heads/other\n")

        let head = GitDirectoryResolver.readHeadHash(gitDirectory: fixture.gitDirectory)

        #expect(head == nil)
    }

    @Test("HEAD 文件缺失时返回 nil")
    func returnsNilWhenHeadMissing() throws {
        let fixture = try GitFixture.makeProject(label: "no-head")

        #expect(GitDirectoryResolver.readHeadHash(gitDirectory: fixture.gitDirectory) == nil)
    }

    @Test("内容指纹对相同内容稳定、对不同内容不同")
    func fingerprintIsStableAndContentSensitive() throws {
        let fixture = try GitFixture.makeProject(label: "fingerprint")
        let file = fixture.gitDirectory.appendingPathComponent("index")
        try Data([1, 2, 3]).write(to: file)

        let first = GitDirectoryResolver.fileContentFingerprint(file)
        let second = GitDirectoryResolver.fileContentFingerprint(file)
        let other = fixture.gitDirectory.appendingPathComponent("other")
        try Data([4, 5, 6]).write(to: other)
        let different = GitDirectoryResolver.fileContentFingerprint(other)

        #expect(first == second)
        #expect(first != different)
        #expect(first != nil)
    }

    @Test("文件不存在时指纹为 nil")
    func fingerprintOfMissingFileIsNil() throws {
        let fixture = try GitFixture.makeProject(label: "no-file")

        let fingerprint = GitDirectoryResolver.fileContentFingerprint(
            fixture.gitDirectory.appendingPathComponent("missing")
        )

        #expect(fingerprint == nil)
    }

    @Test("快照同时汇总 head / index / stash / refs")
    func readsFullSnapshot() throws {
        let fixture = try GitFixture.makeProject(label: "snapshot")
        try fixture.writeGitFile("HEAD", contents: "ref: refs/heads/main\n")
        try fixture.writeGitFile("refs/heads/main", contents: "deadbeef\n")
        try fixture.writeGitFile("index", contents: "index-content")
        try fixture.writeGitFile("refs/stash", contents: "stash-content")

        let snapshot = GitDirectoryResolver.readSnapshot(gitDirectory: fixture.gitDirectory)

        #expect(snapshot.head == "deadbeef")
        #expect(snapshot.index != nil)
        #expect(snapshot.stash != nil)
        #expect(snapshot.refs != nil)
    }

    @Test("空仓库的快照四项均为 nil")
    func emptyRepositorySnapshotIsAllNil() throws {
        let fixture = try GitFixture.makeProject(label: "empty")

        let snapshot = GitDirectoryResolver.readSnapshot(gitDirectory: fixture.gitDirectory)

        #expect(snapshot.head == nil)
        #expect(snapshot.index == nil)
        #expect(snapshot.stash == nil)
        #expect(snapshot.refs == nil)
    }
}

// MARK: - 监听 Provider

@Suite("Git 仓库监听 Provider")
@MainActor
struct GitRepositoryWatchProviderTests {

    @Test("监听真实仓库时广播 started 且监听器就绪")
    func startsWatchingRepository() throws {
        let fixture = try GitFixture.makeProject(label: "provider-start")
        let provider = GitRepositoryWatchProvider()
        var events: [GitRepositoryWatchingEvent] = []
        let handle = provider.addObserver { events.append($0) }
        defer { handle.cancel() }

        provider.startWatching(repositoryURL: fixture.projectURL)

        #expect(provider.watchingRepositoryURL != nil)
        #expect(provider.isWatcherActive)
        #expect(provider.watchedGitDirectoryPath == fixture.gitDirectory.standardizedFileURL.path)
        #expect(events.count == 1)

        provider.stopWatching()
    }

    @Test("项目路径是仓库子目录时正常监听并广播 started（回归 #913）")
    func startsWatchingFromNestedProjectDirectory() throws {
        let fixture = try GitFixture.makeProject(label: "provider-nested")
        let nested = fixture.projectURL.appendingPathComponent("Sources", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let provider = GitRepositoryWatchProvider()
        var events: [GitRepositoryWatchingEvent] = []
        let handle = provider.addObserver { events.append($0) }
        defer { handle.cancel() }

        provider.startWatching(repositoryURL: nested)

        #expect(provider.isWatcherActive)
        #expect(provider.watchedGitDirectoryPath == fixture.gitDirectory.standardizedFileURL.path)
        #expect(events.count == 1)

        provider.stopWatching()
    }

    @Test("监听非仓库目录时不广播 started")
    func ignoresNonRepository() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginGitRepositoryWatchTests-notrepo-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let provider = GitRepositoryWatchProvider()
        var events: [GitRepositoryWatchingEvent] = []
        let handle = provider.addObserver { events.append($0) }
        defer { handle.cancel() }

        provider.startWatching(repositoryURL: root)

        #expect(provider.watchingRepositoryURL == nil)
        #expect(provider.isWatcherActive == false)
        #expect(events.isEmpty)
    }

    @Test("停止监听时广播 stopped")
    func broadcastsStopped() throws {
        let fixture = try GitFixture.makeProject(label: "provider-stop")
        let provider = GitRepositoryWatchProvider()
        var events: [GitRepositoryWatchingEvent] = []
        let handle = provider.addObserver { events.append($0) }
        defer { handle.cancel() }

        provider.startWatching(repositoryURL: fixture.projectURL)
        provider.stopWatching()

        #expect(provider.watchingRepositoryURL == nil)
        #expect(provider.isWatcherActive == false)
        #expect(events.count == 2)
    }

    @Test("重复监听同一目录是幂等的")
    func repeatedStartIsIdempotent() throws {
        let fixture = try GitFixture.makeProject(label: "provider-idempotent")
        let provider = GitRepositoryWatchProvider()
        var events: [GitRepositoryWatchingEvent] = []
        let handle = provider.addObserver { events.append($0) }
        defer { handle.cancel() }

        provider.startWatching(repositoryURL: fixture.projectURL)
        provider.startWatching(repositoryURL: fixture.projectURL)

        #expect(events.count == 1)
        #expect(provider.isWatcherActive)

        provider.stopWatching()
    }

    /// 回归 #921：Git Workspace 面板销毁时只释放 `@StateObject` 持有的订阅令牌，
    /// 从不调用 `cancel()`；若 Provider 强引用回调，每打开一次面板就多一条永久
    /// 注册，之后每次仓库事件都要遍历全部历史回调。
    @Test("释放订阅令牌后不再收到事件（回归 #921）")
    func releasedObserverHandleStopsReceiving() throws {
        let fixture = try GitFixture.makeProject(label: "provider-release")
        let provider = GitRepositoryWatchProvider()
        var events: [GitRepositoryWatchingEvent] = []

        // 作用域结束即释放令牌，模拟面板销毁后无人持有句柄。
        do {
            let handle = provider.addObserver { events.append($0) }
            _ = handle
        }

        provider.startWatching(repositoryURL: fixture.projectURL)
        provider.stopWatching()

        #expect(events.isEmpty, "已释放的订阅令牌仍在接收广播，注册数量会随面板打开次数增长")
    }

    @Test("注销观察者后不再收到事件")
    func cancelledObserverStopsReceiving() throws {
        let fixture = try GitFixture.makeProject(label: "provider-cancel")
        let provider = GitRepositoryWatchProvider()
        var events: [GitRepositoryWatchingEvent] = []
        let handle = provider.addObserver { events.append($0) }

        provider.startWatching(repositoryURL: fixture.projectURL)
        handle.cancel()
        provider.stopWatching()

        #expect(events.count == 1)
    }

    @Test("未监听就停止是安全的")
    func stopWithoutStartIsSafe() {
        let provider = GitRepositoryWatchProvider()

        provider.stopWatching()

        #expect(provider.watchingRepositoryURL == nil)
    }

    /// 回归 #911：FSEvents 的 `IgnoreSelf` 会过滤掉同一进程触发的写入。
    /// 内置编辑器保存发生在 Lumi 进程内，若被过滤，已打开的 Git Changes
    /// 不会收到 `.workingTreeChanged`，只能停留在保存前的状态。
    @Test("进程内写入工作区也会广播 workingTreeChanged（回归 #911）")
    func reportsInProcessWorkingTreeWrites() async throws {
        let fixture = try GitFixture.makeProject(label: "provider-self-write")
        let provider = GitRepositoryWatchProvider()
        var events: [GitRepositoryWatchingEvent] = []
        let handle = provider.addObserver { events.append($0) }
        defer {
            handle.cancel()
            provider.stopWatching()
        }

        provider.startWatching(repositoryURL: fixture.projectURL)
        try await Task.sleep(for: .milliseconds(100))

        // 与编辑器保存一致：由本进程写文件。
        try "saved\n".write(
            to: fixture.projectURL.appendingPathComponent("saved.txt"),
            atomically: true,
            encoding: .utf8
        )

        let sawWorkingTreeChange = await waitUntil(timeout: 5) {
            events.contains {
                if case .workingTreeChanged = $0 { return true }
                return false
            }
        }

        #expect(sawWorkingTreeChange, "进程内保存没有触发 workingTreeChanged，Changes 会停留在旧状态")
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
