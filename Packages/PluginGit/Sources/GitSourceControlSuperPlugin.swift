import KitAgentTool
import EditorContracts
import KernelCore
import ProviderProject
import ProviderToolManager

/// Publishes Git's existing editor-neutral SCM adapter into KernelCore.
///
/// The adapter deliberately remains separate from the later Git workspace and
/// tool migration: editors only depend on SourceControlProviding and therefore
/// regain repository status, baselines, staging, and commits immediately.
@MainActor
public final class GitSourceControlSuperPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.git"
    public let order = 11
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.git",
        name: "Git",
        description: "Git source-control integration for editor status and baselines.",
        category: .project,
        stage: .preview,
        policy: .disabledByDefault
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
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
        for tool in tools {
            kernel.resolveProvider((any ToolManagerProviding).self)?.add(tool, pluginID: id)
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.unregisterProvider((any SourceControlProviding).self)
        for name in GitV2ToolNames.all {
            kernel.resolveProvider((any ToolManagerProviding).self)?.remove(id: name)
        }
    }
}
