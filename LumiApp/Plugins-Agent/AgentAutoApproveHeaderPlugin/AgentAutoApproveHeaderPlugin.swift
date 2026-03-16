import MagicKit
import SwiftUI

/// 自动批准开关插件：右侧栏 header 中的 Auto-Approve 切换
actor AgentAutoApproveHeaderPlugin: SuperPlugin {
    nonisolated static let emoji = "✅"
    nonisolated static let verbose = false

    static let id = "AgentAutoApproveHeader"
    static let displayName = String(localized: "Auto-Approve Toggle", table: "AgentAutoApproveHeader")
    static let description = String(localized: "Auto-approve toggle in chat header", table: "AgentAutoApproveHeader")
    static let iconName = "checkmark.circle"
    static var order: Int { 82 }
    static let enable: Bool = true

    static let shared = AgentAutoApproveHeaderPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func addRightHeaderLeadingView() -> AnyView? { nil }

    @MainActor
    func addRightHeaderTrailingItems() -> [AnyView] {
        [AnyView(AutoApproveToggle())]
    }
}

