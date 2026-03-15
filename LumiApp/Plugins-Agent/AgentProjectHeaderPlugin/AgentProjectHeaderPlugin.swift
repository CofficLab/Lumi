import MagicKit
import SwiftUI

/// 项目管理头部插件：右侧栏 header 左侧（项目信息、选择提示）+ 项目按钮
actor AgentProjectHeaderPlugin: SuperPlugin {
    nonisolated static let emoji = "📁"
    nonisolated static let verbose = false

    static let id = "AgentProjectHeader"
    static let displayName = String(localized: "Project Header", table: "AgentProjectHeader")
    static let description = String(localized: "Project name and selector in chat header", table: "AgentProjectHeader")
    static let iconName = "folder"
    static var order: Int { 81 }
    static let enable: Bool = true

    static let shared = AgentProjectHeaderPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func addRightHeaderView() -> AnyView? { nil }

    @MainActor
    func addRightHeaderLeadingView() -> AnyView? {
        AnyView(ChatHeaderLeadingView())
    }

    @MainActor
    func addRightHeaderTrailingItems() -> [AnyView] {
        [AnyView(ProjectButton())]
    }
}
