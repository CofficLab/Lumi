import MagicKit
import SwiftUI

/// 项目选择头部插件：右侧栏 header 左侧（当前项目信息、未选项目提示）+ 项目按钮
actor AgentProjectHeaderPlugin: SuperPlugin {
    nonisolated static let emoji = "📁"
    nonisolated static let verbose = false

    static let id = "AgentProjectHeader"
    static let displayName = String(localized: "Project Selector", table: "AgentProjectHeader")
    static let description = String(localized: "Select and manage project in chat header", table: "AgentProjectHeader")
    static let iconName = "folder"
    static var order: Int { 81 }
    static let enable: Bool = true

    static let shared = AgentProjectHeaderPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func addRightHeaderLeadingView() -> AnyView? {
        AnyView(ChatHeaderLeadingView())
    }

    @MainActor
    func addRightHeaderTrailingItems() -> [AnyView] {
        [AnyView(ProjectButton())]
    }
}
