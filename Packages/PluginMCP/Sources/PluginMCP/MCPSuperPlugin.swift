import Foundation
import KernelCore
import KitAgentTool
import KitMCP
import KitSuperLog
import ProviderSettingView
import ProviderToolManager
import SwiftUI
import os

/// PluginMCP：Lumi 的 Cursor 式通用 MCP 客户端。
///
/// - 设置页新增"MCP 服务器"入口：添加 / 配置任意 MCP 服务器（stdio / HTTP）；
/// - 已连接服务器的工具自动桥接为 `SuperAgentTool` 并注册进
///   `ToolManagerProviding`，LLM 可直接调用（审批流与内置工具一致）；
/// - 内置 Xcode (native) 预设（`xcrun mcpbridge`）。
@MainActor
public final class MCPSuperPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.mcp",
        category: "MCP"
    )

    public let id = "com.coffic.lumi.plugin.mcp"
    public let order = 270
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.mcp",
        name: "MCP",
        description: "Connect any MCP server (Xcode, GitHub, filesystem, …) and let the agent use its tools, Cursor-style.",
        category: .integration,
        stage: .preview,
        policy: .enabledByDefault
    )

    /// 设置页入口 id（onShutdown 时撤回）。
    public static let settingsEntryID = "com.coffic.lumi.plugin.mcp.settings"

    private var registry: MCPServerRegistry?
    private var manager: MCPConnectionManager?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        let registry = MCPServerRegistry()
        let toolManager = kernel.resolveProvider((any ToolManagerProviding).self)
        let manager = MCPConnectionManager(
            registry: registry,
            toolManager: toolManager,
            pluginID: id
        )
        self.registry = registry
        self.manager = manager

        kernel.resolveProvider((any SettingViewProviding).self)?.addEntries([
            SettingEntryItem(
                id: Self.settingsEntryID,
                title: MCPText.string("MCP Servers"),
                systemImage: "link",
                order: order
            ) { [weak self] in
                guard let self, let registry = self.registry, let manager = self.manager else {
                    return AnyView(EmptyView())
                }
                return AnyView(MCPSettingsView(registry: registry, manager: manager))
            },
        ])

        // 自动连接 autoStart 服务器（不阻塞启动）。
        Task { [weak manager] in
            await manager?.startAutoStartServers()
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        // 同步：先把已注册工具从 ToolManager 移除（LLM 立即不可见）。
        if let manager {
            manager.removeAllToolsSynchronously()
        }
        // 异步：断开全部会话（fire-and-forget，进程退出由会话内部处理）。
        Task { [weak manager] in
            await manager?.disconnectAllSessions()
        }
        kernel.resolveProvider((any SettingViewProviding).self)?
            .removeEntries(ids: [Self.settingsEntryID])
        manager = nil
        registry = nil
    }
}
