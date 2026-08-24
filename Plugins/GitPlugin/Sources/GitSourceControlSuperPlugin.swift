import EditorContracts
import KernelCore

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
    }
}
