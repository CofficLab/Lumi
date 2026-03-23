import MagicKit
import SwiftUI

/// 最近项目持久化插件
/// 负责保存和恢复最近使用的项目列表
actor AgentRecentProjectsPlugin: SuperPlugin {
    nonisolated static let emoji = "📋"
    nonisolated static let verbose = false

    static let id = "AgentRecentProjects"
    static let displayName = String(localized: "Recent Projects", table: "AgentRecentProjects")
    static let description = String(localized: "Persist recent projects list", table: "AgentRecentProjects")
    static let iconName = "clock.arrow.circlepath"
    static var order: Int { 10 }
    static let enable: Bool = true

    static let shared = AgentRecentProjectsPlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func addRootView<Content>(@ViewBuilder content: () -> Content) -> AnyView? where Content: View {
        AnyView(RecentProjectsPersistenceOverlay(content: content()))
    }

    @MainActor
    func addRightHeaderLeadingView() -> AnyView? { nil }

    @MainActor
    func addRightHeaderTrailingItems() -> [AnyView] { [] }

    @MainActor
    func agentTools() -> [AgentTool] {
        [ListRecentProjectsTool()]
    }
}