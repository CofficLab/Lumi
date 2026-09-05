import KernelCore
import KitSuperLog
import os
import ProviderGitRepositoryWatch
import ProviderProject

/// 将真实仓库监听实现注册为可供多个插件复用的 Provider。
@MainActor
public final class GitRepositoryWatchPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.git-repository-watch",
        category: "GitRepositoryWatch"
    )
    public nonisolated static let emoji = "📡"
    public let id = "com.coffic.lumi.plugin.git-repository-watch"
    public let order = 10
    public let dependencies = ["com.coffic.lumi.plugin.projects"]
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.git-repository-watch",
        name: "Git Repository Watch",
        description: "Watch Git repositories and broadcast reusable change events.",
        category: .project,
        stage: .stable,
        policy: .alwaysOn
    )

    private var provider: GitRepositoryWatchProvider?
    private var projectHandle: (any ProjectProvidingObserverHandle)?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let projects = kernel.resolveProvider((any ProjectProviding).self) else {
            Self.logger.error("\(Self.t)ProjectProviding is not registered; skip watcher")
            return
        }

        let provider = GitRepositoryWatchProvider()
        self.provider = provider
        try kernel.registerProvider((any GitRepositoryWatching).self, provider)

        projectHandle = projects.addObserver { [weak provider, weak projects] event in
            guard case .currentProjectChanged = event,
                  let provider,
                  let projects else { return }
            if let path = projects.currentProject?.path, !path.isEmpty {
                provider.startWatching(repositoryURL: URL(fileURLWithPath: path, isDirectory: true))
            } else {
                provider.stopWatching()
            }
        }

        if let path = projects.currentProject?.path, !path.isEmpty {
            provider.startWatching(repositoryURL: URL(fileURLWithPath: path, isDirectory: true))
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        projectHandle?.cancel()
        projectHandle = nil
        provider?.stopWatching()
        provider = nil
        kernel.unregisterProvider((any GitRepositoryWatching).self)
    }
}
