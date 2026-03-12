import MagicKit
import SwiftUI

/// 使用 AppKit 消息列表实现的插件
actor AgentMessagesAppKitPlugin: SuperPlugin {
    nonisolated static let emoji = "💬"
    nonisolated static let verbose = false

    static let id = "DevAssistantMessagesAppKit"
    static let displayName = String(localized: "Dev Assistant Messages (AppKit)", table: "DevAssistant")
    static let description = String(localized: "DevAssistant chat messages (AppKit list)", table: "DevAssistant")
    static let iconName = "text.bubble"
    static var order: Int { 83 }
    static let enable: Bool = false

    static let shared = AgentMessagesAppKitPlugin()

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
    func addDetailMiddleView() -> AnyView? {
        AnyView(ChatMessagesAppKitView())
    }
}

