import AgentToolKit
import Foundation
import KernelCore
import ProviderNetwork
import ProviderToolManager
import SuperLogKit
import os

// MARK: - Show Image SuperPlugin

/// 图片显示插件
///
/// 提供一个 Agent 工具 `show_image`，允许 AI 在聊天 UI 中显示图片。
/// 支持本地文件路径和远程 URL。
///
/// 插件启动时注册工具到 `ToolManagerProviding`，并共享 `ShowImageState`
/// 供 UI 层观察并渲染图片预览。
@MainActor
public final class ShowImagePlugin: SuperPlugin {
    nonisolated public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.show-image")

    public let id = "com.coffic.lumi.plugin.show-image"

    public var metadata: PluginMetadata {
        PluginMetadata(
            id: id,
            name: "Show Image",
            description: "在聊天 UI 中显示图片，支持本地路径和远程 URL",
            category: .chat,
            stage: .stable,
            policy: .alwaysOn
        )
    }

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else { return }

        let network: (any NetworkProviding)? = kernel.resolveProvider((any NetworkProviding).self)
        let tool = ShowImageTool(network: network)
        toolManager.add(tool, pluginID: id)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else { return }
        toolManager.remove(id: ShowImageTool.toolName)
    }
}
