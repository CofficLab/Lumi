import Foundation
import KernelCore
import ProviderGit
import ProviderGitRepositoryWatch
import ProviderProject
import ProviderToolbar
import Testing
@testable import PluginGitToolbar

/// 标题栏分支胶囊的单元测试。
@MainActor
@Suite("Git branch toolbar")
struct GitBranchToolbarTests {
    /// 记录当前项目的轻量替身。
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
    }

    @Test("非 Git 项目时标题栏不出现分支胶囊")
    func nonGitProjectHasNoToolbarItem() async throws {
        let kernel = KernelCoreContainer()
        let toolbar = DefaultToolbarProviding()
        try kernel.registerProvider((any ToolbarProviding).self, toolbar)

        let project = StubProjectProvider()
        project.currentProject = ProjectInfo(name: "plain", path: "/tmp/plain")
        try kernel.registerProvider((any ProjectProviding).self, project)

        let git = InMemoryGitBranchManaging()
        try kernel.registerProvider((any GitBranchManaging).self, git)

        let plugin = GitToolbarPlugin()
        try plugin.onBoot(kernel: kernel)
        defer { try? plugin.onShutdown(kernel: kernel) }

        try await Task.sleep(for: .milliseconds(100))

        #expect(toolbar.toolbarItems.isEmpty)
    }

    @Test("Git 项目下标题栏出现分支胶囊，且位于 center 段")
    func gitProjectAddsCenterToolbarItem() async throws {
        let kernel = KernelCoreContainer()
        let toolbar = DefaultToolbarProviding()
        try kernel.registerProvider((any ToolbarProviding).self, toolbar)

        let project = StubProjectProvider()
        project.currentProject = ProjectInfo(name: "repo", path: "/tmp/repo")
        try kernel.registerProvider((any ProjectProviding).self, project)

        let git = InMemoryGitBranchManaging()
        git.addRepository(atPath: "/tmp/repo")
        git.setCurrentBranch("main", forPath: "/tmp/repo")
        git.setBranches(
            [
                GitBranchInfo(name: "main", isCurrent: true),
                GitBranchInfo(name: "feature", isCurrent: false),
            ],
            forPath: "/tmp/repo"
        )
        try kernel.registerProvider((any GitBranchManaging).self, git)

        let plugin = GitToolbarPlugin()
        try plugin.onBoot(kernel: kernel)
        defer { try? plugin.onShutdown(kernel: kernel) }

        try await Task.sleep(for: .milliseconds(100))

        #expect(toolbar.toolbarItems.count == 1)
        let item = try #require(toolbar.toolbarItems.first)
        #expect(item.id == "\(plugin.id).branch")
        #expect(item.placement == .center)
        #expect(item.category == .project)
        // Projects 胶囊使用 order 0，分支胶囊必须排在它右侧。
        #expect(item.order > 0)
    }

    @Test("切换到其它分支后 ViewModel 的当前分支随之更新")
    func switchingBranchUpdatesCurrentBranch() async throws {
        let git = InMemoryGitBranchManaging()
        git.addRepository(atPath: "/tmp/repo")
        git.setCurrentBranch("main", forPath: "/tmp/repo")
        git.setBranches(
            [
                GitBranchInfo(name: "main", isCurrent: true),
                GitBranchInfo(name: "feature", isCurrent: false),
            ],
            forPath: "/tmp/repo"
        )

        let capability = GitBranchCapabilityAdapter(provider: git)
        let viewModel = GitBranchToolbarViewModel(capability: capability)
        viewModel.updateProject(path: "/tmp/repo")
        try await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.isGitRepository)
        #expect(viewModel.currentBranch == "main")

        let feature = try #require(viewModel.branches.first { $0.name == "feature" })
        await viewModel.switchBranch(to: feature)

        #expect(viewModel.currentBranch == "feature")
    }

    @Test("新建分支后当前分支切换到新分支")
    func creatingBranchSwitchesToIt() async throws {
        let git = InMemoryGitBranchManaging()
        git.addRepository(atPath: "/tmp/repo")
        git.setCurrentBranch("main", forPath: "/tmp/repo")
        git.setBranches([GitBranchInfo(name: "main", isCurrent: true)], forPath: "/tmp/repo")

        let capability = GitBranchCapabilityAdapter(provider: git)
        let viewModel = GitBranchToolbarViewModel(capability: capability)
        viewModel.updateProject(path: "/tmp/repo")
        try await Task.sleep(for: .milliseconds(100))

        await viewModel.createBranch(named: "feature/new")

        #expect(viewModel.currentBranch == "feature/new")
        #expect(viewModel.branches.contains { $0.name == "feature/new" })
    }

    // MARK: - 仓库监听（外部改动分支）

    /// 装配「ViewModel + Observer + 仓库监听」的完整链路。
    private func makeObservedViewModel(
        git: InMemoryGitBranchManaging,
        watch: StubGitRepositoryWatching,
        path: String = "/tmp/repo"
    ) -> (viewModel: GitBranchToolbarViewModel, observer: GitBranchProjectObserver) {
        let project = StubProjectProvider()
        project.currentProject = ProjectInfo(name: "repo", path: path)

        let capability = GitBranchCapabilityAdapter(provider: git, watch: watch)
        let viewModel = GitBranchToolbarViewModel(capability: capability)
        let observer = GitBranchProjectObserver(project: project, viewModel: viewModel)
        observer.observeRepository(capability)
        return (viewModel, observer)
    }

    @Test("外部切分支后胶囊随之刷新")
    func externalBranchChangeRefreshesBranch() async throws {
        let git = InMemoryGitBranchManaging()
        git.addRepository(atPath: "/tmp/repo")
        git.setCurrentBranch("main", forPath: "/tmp/repo")
        git.setBranches([GitBranchInfo(name: "main", isCurrent: true)], forPath: "/tmp/repo")

        let watch = StubGitRepositoryWatching()
        let (viewModel, observer) = makeObservedViewModel(git: git, watch: watch)
        defer { observer.cancel() }
        try await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.currentBranch == "main")

        // 模拟「在终端 / IDE 里切了分支」：仓库状态变化后由 watch 广播事件。
        git.setCurrentBranch("feature", forPath: "/tmp/repo")
        git.setBranches(
            [
                GitBranchInfo(name: "main", isCurrent: false),
                GitBranchInfo(name: "feature", isCurrent: true),
            ],
            forPath: "/tmp/repo"
        )
        watch.send(.headChanged(previousHead: "aaa", head: "bbb"))

        try await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.currentBranch == "feature")
    }

    @Test("外部新建分支后分支列表随之更新")
    func externalBranchCreationUpdatesList() async throws {
        let git = InMemoryGitBranchManaging()
        git.addRepository(atPath: "/tmp/repo")
        git.setCurrentBranch("main", forPath: "/tmp/repo")
        git.setBranches([GitBranchInfo(name: "main", isCurrent: true)], forPath: "/tmp/repo")

        let watch = StubGitRepositoryWatching()
        let (viewModel, observer) = makeObservedViewModel(git: git, watch: watch)
        defer { observer.cancel() }
        try await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.branches.count == 1)

        git.setBranches(
            [
                GitBranchInfo(name: "main", isCurrent: true),
                GitBranchInfo(name: "feature", isCurrent: false),
            ],
            forPath: "/tmp/repo"
        )
        watch.send(.refsChanged)

        try await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.branches.contains { $0.name == "feature" })
    }

    @Test("与分支无关的仓库事件不触发刷新")
    func unrelatedRepositoryEventDoesNotRefresh() async throws {
        let git = InMemoryGitBranchManaging()
        git.addRepository(atPath: "/tmp/repo")
        git.setCurrentBranch("main", forPath: "/tmp/repo")
        git.setBranches([GitBranchInfo(name: "main", isCurrent: true)], forPath: "/tmp/repo")

        let watch = StubGitRepositoryWatching()
        let (viewModel, observer) = makeObservedViewModel(git: git, watch: watch)
        defer { observer.cancel() }
        try await Task.sleep(for: .milliseconds(100))

        // 外部改了仓库状态，但当前分支没变；胶囊不应被无谓地刷新。
        git.setCurrentBranch("feature", forPath: "/tmp/repo")
        watch.send(.indexChanged)
        watch.send(.workingTreeChanged)
        watch.send(.stashChanged)

        try await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.currentBranch == "main")
    }

    @Test("未启用仓库监听时胶囊仍可正常工作")
    func worksWithoutRepositoryWatch() async throws {
        let git = InMemoryGitBranchManaging()
        git.addRepository(atPath: "/tmp/repo")
        git.setCurrentBranch("main", forPath: "/tmp/repo")
        git.setBranches([GitBranchInfo(name: "main", isCurrent: true)], forPath: "/tmp/repo")

        // 不传 watch：模拟未安装 PluginGitRepositoryWatch 的环境。
        let capability = GitBranchCapabilityAdapter(provider: git)
        let viewModel = GitBranchToolbarViewModel(capability: capability)
        viewModel.updateProject(path: "/tmp/repo")
        try await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.isGitRepository)
        #expect(viewModel.currentBranch == "main")
    }

    @Test("插件装配后订阅仓库监听，外部切分支可刷新胶囊")
    func pluginSubscribesRepositoryWatch() async throws {
        let kernel = KernelCoreContainer()
        let toolbar = DefaultToolbarProviding()
        try kernel.registerProvider((any ToolbarProviding).self, toolbar)

        let project = StubProjectProvider()
        project.currentProject = ProjectInfo(name: "repo", path: "/tmp/repo")
        try kernel.registerProvider((any ProjectProviding).self, project)

        let git = InMemoryGitBranchManaging()
        git.addRepository(atPath: "/tmp/repo")
        git.setCurrentBranch("main", forPath: "/tmp/repo")
        git.setBranches([GitBranchInfo(name: "main", isCurrent: true)], forPath: "/tmp/repo")
        try kernel.registerProvider((any GitBranchManaging).self, git)

        let watch = StubGitRepositoryWatching()
        try kernel.registerProvider((any GitRepositoryWatching).self, watch)

        let plugin = GitToolbarPlugin()
        try plugin.onBoot(kernel: kernel)
        defer { try? plugin.onShutdown(kernel: kernel) }

        try await Task.sleep(for: .milliseconds(100))

        #expect(watch.observerCount == 1)
        #expect(toolbar.toolbarItems.count == 1)
    }
}
