import MagicKit
import SwiftUI

/// DevAssistant 消息插件 - 负责显示聊天消息列表
actor DevAssistantMessagesPlugin: SuperPlugin {
    nonisolated static let emoji = "💬"
    nonisolated static let verbose = false

    static let id = "DevAssistantMessages"
    static let displayName = String(localized: "Dev Assistant Messages", table: "DevAssistant")
    static let description = String(localized: "DevAssistant chat messages", table: "DevAssistant")
    static let iconName = "text.bubble.fill"
    static var order: Int { 82 }

    static let shared = DevAssistantMessagesPlugin()

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
    func addSettingsView() -> AnyView? {
        return AnyView(DevAssistantSettingsView())
    }

    @MainActor
    func addDetailMiddleView() -> AnyView? {
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
