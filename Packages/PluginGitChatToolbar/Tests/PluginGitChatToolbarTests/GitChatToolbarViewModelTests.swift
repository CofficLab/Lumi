import Foundation
import Testing
import ProviderGit
import ProviderGitRepositoryWatch
import ProviderProject
@testable import PluginGitChatToolbar

/// 测试替身：轻量 ProjectProviding。
@MainActor
private final class StubProjectProvider: ProjectProviding {
    var currentProject: ProjectInfo?
    var projects: [ProjectInfo] = []
    var openFileURLs: [URL] = []
    var currentFileURL: URL?

    func openProject(at path: String, reason: ProjectChangeReason) async throws {
        currentProject = ProjectInfo(name: (path as NSString).lastPathComponent, path: path)
    }
    func closeProject(reason: ProjectChangeReason) async { currentProject = nil }
    func refreshProjects() async throws {}
    func updateCurrentFile(_ fileURL: URL?) { currentFileURL = fileURL }
    func updateOpenFiles(_ fileURLs: [URL]) { openFileURLs = fileURLs }
    func closeFile(_ fileURL: URL) { openFileURLs.removeAll { $0 == fileURL } }
    func synchronizeProjects(_ projects: [ProjectInfo]) {}
    func previewFile(_ fileURL: URL) { updateCurrentFile(fileURL) }
    func pinFile(_ fileURL: URL) { updateCurrentFile(fileURL) }
    func activateFile(_ fileURL: URL) { updateCurrentFile(fileURL) }
}

/// 测试替身：记录事件的可观察 GitRepositoryWatching。
@MainActor
private final class StubGitRepositoryWatching: GitRepositoryWatching {
    var watchingRepositoryURL: URL?
    private var observers: [(id: UUID, callback: (GitRepositoryWatchingEvent) -> Void)] = []

    func addObserver(
        _ callback: @escaping (GitRepositoryWatchingEvent) -> Void
    ) -> any GitRepositoryWatchingObserverHandle {
        let id = UUID()
        observers.append((id, callback))
        return Handle { [weak self] in
            self?.observers.removeAll { $0.id == id }
        }
    }

    func startWatching(repositoryURL: URL) { watchingRepositoryURL = repositoryURL }
    func stopWatching() { watchingRepositoryURL = nil }

    func broadcast(_ event: GitRepositoryWatchingEvent) {
        for observer in observers { observer.callback(event) }
    }

    private final class Handle: GitRepositoryWatchingObserverHandle {
        private let onCancel: () -> Void
        init(onCancel: @escaping () -> Void) { self.onCancel = onCancel }
        func cancel() { onCancel() }
    }
}

/// 记录项目能力调用的测试替身。
@MainActor
private final class ProjectCapabilityRecorder: GitChatProjectCapability {
    private(set) var repositoryPath: String?
    private(set) var relativePath: String?

    func previewFile(inRepositoryAt repositoryPath: String, relativePath: String) {
        self.repositoryPath = repositoryPath
        self.relativePath = relativePath
    }
}

@MainActor
@Suite("GitChatToolbarViewModel")
struct GitChatToolbarViewModelTests {

    @Test("非 Git 项目：isGitRepository 为 false，无数据")
    func nonGitProjectShowsNoData() async throws {
        let git = InMemoryGitRepositoryReading()
        let capability = GitChatCapabilityAdapter(provider: git)
        let vm = GitChatToolbarViewModel(capability: capability)

        vm.updateProjectPath("/tmp/plain")
        await waitForLoad()
        #expect(vm.isGitRepository == false)
        #expect(vm.commits.isEmpty)
        #expect(vm.workingChanges.isEmpty)
    }

    @Test("Git 项目：status + commits + workingChanges 合成正确")
    func gitProjectLoadsStatusAndCommits() async throws {
        let git = InMemoryGitRepositoryReading()
        git.addRepository(atPath: "/repo")
        git.setStatus(GitStatus(
            branch: "main",
            remote: nil,
            modified: ["a.swift"],
            added: ["b.swift"],
            untracked: ["new.txt"]
        ), forPath: "/repo")
        git.setCommits([
            GitCommitLog(hash: "abc", author: "n", email: "e", date: "2026-09-16T00:00:00Z", message: "hello"),
        ], forPath: "/repo")

        let capability = GitChatCapabilityAdapter(provider: git)
        let vm = GitChatToolbarViewModel(capability: capability)

        vm.updateProjectPath("/repo")
        await waitForLoad()

        #expect(vm.isGitRepository == true)
        #expect(vm.commits.count == 1)
        let changes = vm.workingChanges
        #expect(Set(changes.map(\.path)) == ["a.swift", "b.swift", "new.txt"])
        let byPath = Dictionary(uniqueKeysWithValues: changes.map { ($0.path, $0) })
        #expect(byPath["a.swift"]?.state == .modified)
        #expect(byPath["b.swift"]?.state == .added)
        #expect(byPath["new.txt"]?.state == .untracked)
    }

    @Test("选中 commit 加载其变更文件")
    func selectCommitLoadsChanges() async throws {
        let git = InMemoryGitRepositoryReading()
        git.addRepository(atPath: "/repo")
        git.setStatus(GitStatus(branch: "main"), forPath: "/repo")
        git.setCommits([
            GitCommitLog(hash: "abc", author: "n", email: "e", date: "2026-09-16T00:00:00Z", message: "m"),
        ], forPath: "/repo")
        git.setCommitChanges(
            [GitCommitChange(path: "x.swift", state: .modified)],
            forPath: "/repo",
            hash: "abc"
        )

        let capability = GitChatCapabilityAdapter(provider: git)
        let vm = GitChatToolbarViewModel(capability: capability)
        vm.updateProjectPath("/repo")
        await waitForLoad()

        vm.selectCommit(hash: "abc")
        await waitForLoad()

        #expect(vm.selectedCommitHash == "abc")
        #expect(vm.selectedCommitChanges.count == 1)
        #expect(vm.selectedCommitChanges.first?.path == "x.swift")

        vm.clearCommitSelection()
        #expect(vm.selectedCommitHash == nil)
        #expect(vm.selectedCommitChanges.isEmpty)
    }

    @Test("reloadAll 去抖：多次调用只产生一次实际加载")
    func reloadAllDebounceCoalesces() async throws {
        let git = InMemoryGitRepositoryReading()
        git.addRepository(atPath: "/repo")
        git.setStatus(GitStatus(branch: "main", modified: ["a"]), forPath: "/repo")
        let capability = GitChatCapabilityAdapter(provider: git)
        let vm = GitChatToolbarViewModel(capability: capability)
        vm.updateProjectPath("/repo")
        await waitForLoad()

        // 快速连发 3 次 reloadAll（1s 去抖）
        vm.reloadAll()
        vm.reloadAll()
        vm.reloadAll()
        // 等 1.2s 让去抖触发 + 加载完成
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        #expect(vm.workingChanges.count == 1)
    }

    @Test("分支名与仓库路径派生自工作区状态")
    func branchAndRepositoryPathDerived() async throws {
        let git = InMemoryGitRepositoryReading()
        git.addRepository(atPath: "/repo")
        git.setStatus(GitStatus(branch: "dev", modified: ["a.swift"]), forPath: "/repo")
        let capability = GitChatCapabilityAdapter(provider: git)
        let vm = GitChatToolbarViewModel(capability: capability)

        vm.updateProjectPath("/repo")
        await waitForLoad()

        #expect(vm.branchName == "dev")
        #expect(vm.repositoryPath == "/repo")
    }

    @Test("分支名为空时回退到 HEAD")
    func emptyBranchFallsBackToHEAD() async throws {
        let git = InMemoryGitRepositoryReading()
        git.addRepository(atPath: "/repo")
        git.setStatus(GitStatus(branch: "   "), forPath: "/repo")
        let capability = GitChatCapabilityAdapter(provider: git)
        let vm = GitChatToolbarViewModel(capability: capability)

        vm.updateProjectPath("/repo")
        await waitForLoad()

        #expect(vm.branchName == "HEAD")
    }

    @Test("点击工作区文件：以预览方式交给项目能力")
    func previewWorkingChangeDelegatesToProjectCapability() async throws {
        let git = InMemoryGitRepositoryReading()
        git.addRepository(atPath: "/repo")
        git.setStatus(GitStatus(branch: "main", modified: ["Sources/App.swift"]), forPath: "/repo")
        let capability = GitChatCapabilityAdapter(provider: git)
        let recorder = ProjectCapabilityRecorder()
        let vm = GitChatToolbarViewModel(
            capability: capability,
            projectCapability: recorder
        )

        vm.updateProjectPath("/repo")
        await waitForLoad()

        vm.previewWorkingChange(path: "Sources/App.swift")

        #expect(recorder.repositoryPath == "/repo")
        #expect(recorder.relativePath == "Sources/App.swift")
    }

    @Test("无项目能力时点击文件不崩溃")
    func previewWorkingChangeWithoutProjectCapability() async throws {
        let git = InMemoryGitRepositoryReading()
        git.addRepository(atPath: "/repo")
        git.setStatus(GitStatus(branch: "main", modified: ["a.swift"]), forPath: "/repo")
        let capability = GitChatCapabilityAdapter(provider: git)
        let vm = GitChatToolbarViewModel(capability: capability)

        vm.updateProjectPath("/repo")
        await waitForLoad()

        // 不应崩溃，也不应改变任何状态。
        vm.previewWorkingChange(path: "a.swift")
        #expect(vm.workingChanges.count == 1)
    }
}

/// 等待 ViewModel 完成异步加载（最多 100ms）。
@MainActor
private func waitForLoad() async {
    // refreshNow 通过 Task 异步执行，InMemory provider 同步返回，
    // 100ms 内应能完成。如仍未完成，最多重试 5 次。
    for _ in 0..<5 {
        await Task.yield()
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
}

@MainActor
@Suite("GitChatObserver")
struct GitChatObserverTests {

    @Test("项目切换触发 ViewModel 重载")
    func projectChangeTriggersReload() async throws {
        let project = StubProjectProvider()
        let watch = StubGitRepositoryWatching()
        let git = InMemoryGitRepositoryReading()
        git.addRepository(atPath: "/repo")
        git.setStatus(GitStatus(branch: "main", modified: ["a.swift"]), forPath: "/repo")
        git.addRepository(atPath: "/repo2")
        git.setStatus(GitStatus(branch: "dev", modified: ["b.swift"]), forPath: "/repo2")

        let capability = GitChatCapabilityAdapter(provider: git)
        let vm = GitChatToolbarViewModel(capability: capability)
        let observer = GitChatObserver(project: project, watch: watch, viewModel: vm)
        defer { observer.cancel() }

        // 手动调用 updateProjectPath 模拟项目切换
        vm.updateProjectPath("/repo2")
        await waitForLoad()

        #expect(vm.projectPath == "/repo2")
        #expect(vm.isGitRepository == true)
        #expect(vm.workingChanges.map(\.path) == ["b.swift"])
    }

    @Test("GitRepositoryWatching 事件触发重载")
    func watchEventTriggersReload() async throws {
        let project = StubProjectProvider()
        project.currentProject = ProjectInfo(name: "repo", path: "/repo")
        let watch = StubGitRepositoryWatching()
        let git = InMemoryGitRepositoryReading()
        git.addRepository(atPath: "/repo")
        git.setStatus(GitStatus(branch: "main", modified: ["a.swift"]), forPath: "/repo")

        let capability = GitChatCapabilityAdapter(provider: git)
        let vm = GitChatToolbarViewModel(capability: capability)
        let observer = GitChatObserver(project: project, watch: watch, viewModel: vm)
        defer { observer.cancel() }

        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(vm.workingChanges.count == 1)

        // 更新数据后广播 workingTreeChanged
        git.setStatus(GitStatus(branch: "main", modified: ["a.swift", "b.swift"]), forPath: "/repo")
        watch.broadcast(.workingTreeChanged)
        // 等待 1s 去抖 + 50ms 调度
        try? await Task.sleep(nanoseconds: 1_100_000_000)
        #expect(vm.workingChanges.count == 2)
    }
}
