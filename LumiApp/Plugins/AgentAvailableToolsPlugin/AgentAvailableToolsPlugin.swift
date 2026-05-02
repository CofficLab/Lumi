import MagicKit
import os
import SwiftUI

/// 可用工具插件
///
/// 在状态栏右侧提供可用工具按钮（AvailableToolsButton）。
actor AgentAvailableToolsPlugin: SuperPlugin, SuperLog {
    nonisolated static let emoji = "🧰"
    nonisolated static let verbose: Bool = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-available-tools")

    static let id = "AgentAvailableToolsPlugin"
    static let displayName = String(localized: "Tools", table: "AgentAvailableToolsPlugin")
    static let description = String(localized: "Show all available tools", table: "AgentAvailableToolsPlugin")
    static let iconName = "wrench.and.screwdriver"
    static var order: Int { 85 }

    /// 用户可在设置中启用/禁用此插件
    static var isConfigurable: Bool { true }

    static let enable: Bool = true

    static let shared = AgentAvailableToolsPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    // MARK: - StatusBar Views

    /// 状态栏右侧：可用工具按钮
    @MainActor
    func addStatusBarTrailingView(activeIcon: String?) -> AnyView? {
        AnyView(AvailableToolsButton())
    }
}
