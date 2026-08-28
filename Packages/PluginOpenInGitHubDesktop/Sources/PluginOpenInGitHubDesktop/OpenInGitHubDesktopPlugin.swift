import os
import Foundation
import KernelCore
import KitSuperLog
import OpenInKit
import ProviderProject
import ProviderToolManager

/// 在 GitHub Desktop 中打开项目的插件。
@MainActor
public final class OpenInGitHubDesktopPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.open-in-github-desktop", category: "OpenInGitHubDesktop")

    public let id = "com.coffic.lumi.plugin.open-in-github-desktop"
    public let order = 615
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.open-in-github-desktop",
        name: "Open In GitHub Desktop",
        description: "Allow LLM to open projects in GitHub Desktop.",
        category: .integration,
        stage: .stable,
        policy: .enabledByDefault
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolManagerProviding from kernel")
            return
        }
        let project = kernel.resolveProvider((any ProjectProviding).self)

        let tool = OpenInTool(config: .gitHubDesktop, project: project)
        toolManager.add(tool, pluginID: id)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolManagerProviding from kernel")
            return
        }
        toolManager.remove(id: OpenInTool.gitHubDesktop.toolName)
    }
}