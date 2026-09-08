import EditorContracts
import KernelCore
import KitAgentTool
import KitSuperLog
import os
import ProviderMessageRendering
import ProviderProject
import ProviderSkill
import ProviderToolManager

/// Publishes Git's existing editor-neutral SCM adapter into KernelCore.
///
/// The adapter deliberately remains separate from the later Git workspace and
/// tool migration: editors only depend on SourceControlProviding and therefore
/// regain repository status, baselines, staging, and commits immediately.
@MainActor
public final class GitSourceControlSuperPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.git", category: "GitSourceControl")

    public nonisolated static let pluginID = "com.coffic.lumi.plugin.git"
    public nonisolated static let emoji = "🌿"
    nonisolated static let verbose = false

    public let id = GitSourceControlSuperPlugin.pluginID
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
        let projectCapability = project.map { GitProjectCapabilityAdapter(project: $0) }
        let tools: [any SuperAgentTool] = [
            GitStatusV2Tool(project: projectCapability),
            GitDiffV2Tool(project: projectCapability),
            GitLogTool(project: projectCapability),
            GitShowV2Tool(project: projectCapability),
            GitBranchV2Tool(project: projectCapability),
            GitCommitV2Tool(project: projectCapability),
            GitUnpushedV2Tool(project: projectCapability),
        ]
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolManagerProviding; Git tools were not registered")
            return
        }
        for tool in tools {
            toolManager.add(tool, pluginID: id)
        }
        
        // 注册 git_log 工具结果的专用行渲染器：
        // LLM 调用 git_log 后，消息列表以 commit 卡片形式展示最近提交。
        kernel.resolveProvider((any ToolCallRenderingProviding).self)?
            .register(GitLogRowRenderer())
        
        // 向 SkillProviding 贡献 Git 技能（幂等注入）。
        if let skillProvider = kernel.resolveProvider((any SkillProviding).self) {
            if !skillProvider.isProviderRegistered(providerID: id) {
                let contributor = GitSkillContributor(providerID: id)
                skillProvider.addProvider(contributor)
                if Self.verbose {
                    Self.logger.info("\(Self.t)Contributed \(contributor.allSkills.count) skill(s) via SkillProviding")
                }
            }
        }
        
        if Self.verbose {
            Self.logger.info("\(Self.t)Registered Git source-control provider and \(tools.count) tools")
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        Self.logger.info("\(Self.t)Shutting down Git source-control plugin")
        kernel.unregisterProvider((any SourceControlProviding).self)
        kernel.resolveProvider((any ToolCallRenderingProviding).self)?
            .unregister(id: GitLogRowRenderer.id)
        for name in GitV2ToolNames.all {
            kernel.resolveProvider((any ToolManagerProviding).self)?.remove(id: name)
        }
        Self.logger.info("\(Self.t)Unregistered Git source-control provider and removed Git tools")

        // 撤回 Git 技能贡献。
        kernel.resolveProvider((any SkillProviding).self)?
            .removeProvider(providerID: id)
    }
}
