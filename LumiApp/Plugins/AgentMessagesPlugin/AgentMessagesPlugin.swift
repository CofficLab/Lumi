import MagicKit
import SwiftUI

/// 消息插件 - 负责显示聊天消息列表
actor AgentMessagesPlugin: SuperPlugin {
    nonisolated static let emoji = "💬"
    nonisolated static let verbose = false

    static let id = "DevAssistantMessages"
    static let displayName = String(localized: "Dev Assistant Messages", table: "DevAssistant")
    static let description = String(localized: "DevAssistant chat messages", table: "DevAssistant")
    static let iconName = "text.bubble.fill"
    static var order: Int { 82 }
    static let enable: Bool = true

    static let shared = AgentMessagesPlugin()

    // MARK: - Lifecycle

    nonisolated func onRegister() {
        // Init
    }

    nonisolated func onEnable() {
        // Init
    }

    nonisolated func onDisable() {
        // Cleanup
    }

    // MARK: - UI

    @MainActor
    func addRightMiddleView() -> AnyView? {
        return AnyView(ChatMessagesView())
    }
}

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .withNavigation("dev_assistant")
        .inRootView()
        .withDebugBar()
}
