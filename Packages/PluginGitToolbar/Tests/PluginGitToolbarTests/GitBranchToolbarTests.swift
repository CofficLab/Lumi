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

    @Test("detached HEAD 时 ViewModel 不再把 OID 当分支名")
    func detachedHeadKeepsBranchEmptyAndExposesHash() async throws {
        let fullHash = "8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d3e2f1a0b9c"
        let git = InMemoryGitBranchManaging()
        git.addRepository(atPath: "/tmp/repo")
        git.setCurrentBranch(nil, forPath: "/tmp/repo")
        git.setDetachedHeadCommitHash(fullHash, forPath: "/tmp/repo")

        let capability = GitBranchCapabilityAdapter(provider: git)
        let viewModel = GitBranchToolbarViewModel(capability: capability)
        viewModel.updateProject(path: "/tmp/repo")
        try await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.currentBranch == nil)
        #expect(viewModel.detachedHeadCommitHash == fullHash)
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

    // MARK: - 加载错误恢复

    /// 前 N 次 `currentBranch` 读取失败、之后正常的替身。
    @MainActor
    private final class FlakyBranchCapability: GitBranchCapability, @unchecked Sendable {
        struct SimulatedReadError: LocalizedError {
            var errorDescription: String? { "simulated branch read failure" }
        }

        private var remainingFailures: Int
        private let base: GitBranchCapabilityAdapter
        private let watch = StubGitRepositoryWatching()

        init(failures: Int, git: InMemoryGitBranchManaging) {
            remainingFailures = failures
            base = GitBranchCapabilityAdapter(provider: git, watch: watch)
        }

        func isRepository(atPath path: String) async -> Bool {
            await base.isRepository(atPath: path)
        }

        func currentBranch(atPath path: String) async throws -> String? {
            if remainingFailures > 0 {
                remainingFailures -= 1
                throw SimulatedReadError()
            }
            return try await base.currentBranch(atPath: path)
        }

        func detachedHeadCommitHash(atPath path: String) async throws -> String? {
            try await base.detachedHeadCommitHash(atPath: path)
        }

        func listBranches(atPath path: String, includeRemote: Bool) async throws -> [GitBranchInfo] {
            try await base.listBranches(atPath: path, includeRemote: includeRemote)
        }

        func checkout(branch: String, atPath path: String) async throws {
            try await base.checkout(branch: branch, atPath: path)
        }

        func createBranch(named name: String, atPath path: String) async throws {
            try await base.createBranch(named: name, atPath: path)
        }

        func addRepositoryObserver(
            _ callback: @escaping (GitRepositoryWatchingEvent) -> Void
        ) -> (any GitRepositoryWatchingObserverHandle)? {
            base.addRepositoryObserver(callback)
        }

        func send(_ event: GitRepositoryWatchingEvent) {
            watch.send(event)
        }
    }

    @Test("加载恢复后 watcher 触发的成功刷新会清除旧错误横幅（回归 #914）")
    func successfulRefreshClearsStaleLoadError() async throws {
        let git = InMemoryGitBranchManaging()
        git.addRepository(atPath: "/tmp/repo")
        git.setCurrentBranch("main", forPath: "/tmp/repo")
        git.setBranches([GitBranchInfo(name: "main", isCurrent: true)], forPath: "/tmp/repo")

        let capability = FlakyBranchCapability(failures: 1, git: git)
        let project = StubProjectProvider()
        project.currentProject = ProjectInfo(name: "repo", path: "/tmp/repo")
        let viewModel = GitBranchToolbarViewModel(capability: capability)
        let observer = GitBranchProjectObserver(project: project, viewModel: viewModel)
        observer.observeRepository(capability)
        defer { observer.cancel() }
        try await Task.sleep(for: .milliseconds(100))

        // 首次加载失败：横幅出现，分支数据为空。
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.branches.isEmpty)

        // 仓库恢复可读后，watcher 广播事件触发第二次加载并成功。
        capability.send(.refsChanged)
        try await Task.sleep(for: .milliseconds(100))

        #expect(viewModel.currentBranch == "main")
        #expect(!viewModel.branches.isEmpty)
        #expect(viewModel.errorMessage == nil, "成功刷新后不应继续显示已恢复的加载错误")
    }

    @Test("用户切换分支失败的错误不会被随后的成功刷新清除（回归 #914）")
    func operationFailureSurvivesSuccessfulRefresh() async throws {
        let git = InMemoryGitBranchManaging(checkoutFailures: ["feature": "checkout refused"])
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

        let feature = try #require(viewModel.branches.first { $0.name == "feature" })
        await viewModel.switchBranch(to: feature)

        // 切换失败后的 reload 会成功，但那是操作错误，不是加载错误。
        #expect(viewModel.currentBranch == "main")
        #expect(viewModel.errorMessage != nil)
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
