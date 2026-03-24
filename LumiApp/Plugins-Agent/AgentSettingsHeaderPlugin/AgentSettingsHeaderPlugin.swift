import MagicKit
import SwiftUI

/// 设置按钮头部插件：右侧栏 header 中的设置按钮
actor AgentSettingsHeaderPlugin: SuperPlugin {
    nonisolated static let emoji = "⚙️"
    nonisolated static let verbose = false

    static let id = "AgentSettingsHeader"
    static let displayName = String(localized: "Settings Button", table: "AgentSettingsHeader")
    static let description = String(localized: "Open settings from header", table: "AgentSettingsHeader")
    static let iconName = "gearshape"
    static var order: Int { 84 }
    
    /// 用户可在设置中启用/禁用此插件
    static var isConfigurable: Bool { true }
    
    static let enable: Bool = true

    static let shared = AgentSettingsHeaderPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func addRightHeaderLeadingView() -> AnyView? { nil }

    @MainActor
    func addRightHeaderTrailingItems() -> [AnyView] {
        [AnyView(SettingsButton())]
    }
}
