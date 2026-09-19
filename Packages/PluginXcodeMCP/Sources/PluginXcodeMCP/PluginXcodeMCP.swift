import Foundation
import KernelCore
import KitMCP
import ProviderMCP
import KitSuperLog
import os

/// PluginXcodeMCP：贡献 Xcode 原生 MCP 服务器模板。
///
/// 不自带设置 UI，不管理连接——只负责在启动时把
/// `xcrun mcpbridge` 的服务器配置贡献给 PluginMCP 的收集器。
/// 用户在 PluginMCP 设置里启用后，由 PluginMCP 负责连接和工具桥接。
@MainActor
public final class PluginXcodeMCP: SuperPlugin, SuperLog {
    nonisolated public static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.xcode-mcp",
        category: "XcodeMCP"
    )

    public let id = "com.coffic.lumi.plugin.xcode-mcp"
    public let order = 280
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.xcode-mcp",
        name: "Xcode MCP",
        description: "Contributes the native Xcode MCP server (xcrun mcpbridge).",
        category: .integration,
        stage: .preview,
        policy: .required
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        // PluginMCP (order 270) 先 boot 并注册贡献收集器，这里再 resolve 并贡献。
        kernel.resolveProvider((any MCPServerContributionProviding).self)?.contribute(
            MCPServerConfig(
                name: "Xcode (native)",
                command: "xcrun",
                arguments: ["mcpbridge"]
            )
        )
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {}
}
