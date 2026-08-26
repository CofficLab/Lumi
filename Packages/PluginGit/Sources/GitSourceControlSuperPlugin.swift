import EditorContracts
import KernelCore
import KitAgentTool
import KitSuperLog
import os
import ProviderProject
import ProviderToolManager

/// Publishes Git's existing editor-neutral SCM adapter into KernelCore.
///
/// The adapter deliberately remains separate from the later Git workspace and
/// tool migration: editors only depend on SourceControlProviding and therefore
/// regain repository status, baselines, staging, and commits immediately.
@MainActor
public final class GitSourceControlSuperPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.git", category: "GitSourceControl")
    public nonisolated static let emoji = "🌿"
    nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.git"
    public let order = 11
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.git",
        name: "Git",
        description: "Git source-control integration for editor status and baselines.",
        category: .project,
        stage: .preview,
        policy: .required
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)Booting Git source-control plugin")
        }
        
        try kernel.registerProvider((any SourceControlProviding).self, GitSourceControlAdapter())
        let project = kernel.resolveProvider((any ProjectProviding).self)
        let tools: [any SuperAgentTool] = [
            GitStatusV2Tool(project: project),
            GitDiffV2Tool(project: project),
            GitLogV2Tool(project: project),
            GitShowV2Tool(project: project),
            GitBranchV2Tool(project: project),
            GitCommitV2Tool(project: project),
            GitUnpushedV2Tool(project: project),
        ]
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolManagerProviding; Git tools were not registered")
            return
        }
        for tool in tools {
            toolManager.add(tool, pluginID: id)
        }
        
        if Self.verbose {
            Self.logger.info("\(Self.t)Registered Git source-control provider and \(tools.count) tools")
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        Self.logger.info("\(Self.t)Shutting down Git source-control plugin")
        kernel.unregisterProvider((any SourceControlProviding).self)
        for name in GitV2ToolNames.all {
            kernel.resolveProvider((any ToolManagerProviding).self)?.remove(id: name)
        }
        Self.logger.info("\(Self.t)Unregistered Git source-control provider and removed Git tools")
    }
}
