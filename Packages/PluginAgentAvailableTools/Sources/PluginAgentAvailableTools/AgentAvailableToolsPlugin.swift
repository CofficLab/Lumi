import os
import SuperLogKit
import SwiftUI
import LumiCoreKit

/// 可用工具插件
///
/// 在状态栏右侧提供可用工具按钮（AvailableToolsButton）。
public actor AgentAvailableToolsPlugin: SuperPlugin, SuperLog {
    public nonisolated static let emoji = "🧰"
    public nonisolated static let verbose: Bool = true
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-available-tools")

    public static let id = "AgentAvailableToolsPlugin"
    public static let displayName = String(localized: "Tools", table: "AgentAvailableToolsPlugin")
    public static let description = String(localized: "Show all available tools", table: "AgentAvailableToolsPlugin")
    public static let iconName = "wrench.and.screwdriver"
    public static var category: PluginCategory { .agent }
    public static var order: Int { 85 }
    public static let policy: PluginPolicy = .optOut

    /// 用户可在设置中启用/禁用此插件

    public static let shared = AgentAvailableToolsPlugin()

    public nonisolated func onRegister() {}
    public nonisolated func onEnable() {}
    public nonisolated func onDisable() {}

    // MARK: - StatusBar Views

    /// 状态栏右侧：可用工具按钮（仅在编辑器激活时显示）
    @MainActor
    public func addStatusBarTrailingView(context: PluginContext) -> AnyView? {
        nil
    }
}
