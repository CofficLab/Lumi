import MagicKit
import SwiftUI

/// 可用工具插件
actor AgentAvailableToolsPlugin: SuperPlugin {
    nonisolated static let emoji = "🧰"
    nonisolated static let verbose: Bool = false
    static let id = "AgentAvailableToolsHeader"
    static let displayName = String(localized: "Tools", table: "AgentAvailableToolsHeader")
    static let description = String(localized: "Show all available tools", table: "AgentAvailableToolsHeader")
    static let iconName = "wrench.and.screwdriver"
    static var order: Int { 85 }
    
    /// 用户可在设置中启用/禁用此插件
    static var isConfigurable: Bool { true }
    
    static let enable: Bool = true

    static let shared = AgentAvailableToolsPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func addRightHeaderLeadingView() -> AnyView? { nil }

    @MainActor
    func addRightHeaderTrailingItems() -> [AnyView] {
        [AnyView(AvailableToolsButton())]
    }
}
