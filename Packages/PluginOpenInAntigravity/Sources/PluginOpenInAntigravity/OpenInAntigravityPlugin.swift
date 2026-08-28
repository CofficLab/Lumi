import os
import Foundation
import KernelCore
import KitSuperLog
import OpenInKit
import ProviderProject
import ProviderToolManager

/// 在 Antigravity 中打开项目的插件。
@MainActor
public final class OpenInAntigravityPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.open-in-antigravity", category: "OpenInAntigravity")

    public let id = "com.coffic.lumi.plugin.open-in-antigravity"
    public let order = 614
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.open-in-antigravity",
        name: "Open In Antigravity",
        description: "Allow LLM to open projects in Antigravity.",
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

        let tool = OpenInTool(config: OpenInTool.antigravity, project: project)
        toolManager.add(tool, pluginID: id)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolManagerProviding from kernel")
            return
        }
        toolManager.remove(id: OpenInTool.antigravity.toolName)
    }
}