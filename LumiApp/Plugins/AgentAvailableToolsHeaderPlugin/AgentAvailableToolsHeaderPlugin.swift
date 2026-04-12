import MagicKit
import SwiftUI

/// 可用工具头部插件：右侧栏 header 中展示"可用工具"按钮
actor AgentAvailableToolsHeaderPlugin: SuperPlugin {
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

    static let shared = AgentAvailableToolsHeaderPlugin()

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
