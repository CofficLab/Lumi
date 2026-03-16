import MagicKit
import SwiftUI

/// 语言切换头部插件：右侧栏 header 中的语言选择器
actor AgentLanguageHeaderPlugin: SuperPlugin {
    nonisolated static let emoji = "🌐"
    nonisolated static let verbose = false

    static let id = "AgentLanguageHeader"
    static let displayName = String(localized: "Language Selector", table: "AgentLanguageHeader")
    static let description = String(localized: "AI response language in header", table: "AgentLanguageHeader")
    static let iconName = "globe"
    static var order: Int { 83 }
    static let enable: Bool = true

    static let shared = AgentLanguageHeaderPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func addRightHeaderLeadingView() -> AnyView? { nil }

    @MainActor
    func addRightHeaderTrailingItems() -> [AnyView] {
        [AnyView(LanguageSelector())]
    }
}
