import Foundation
import MagicKit
import os
import SwiftUI

/// Conversation List Plugin: 对话历史列表
///
/// 在工具栏右侧提供会话列表入口（ConversationListPopoverButton）。
actor ConversationListPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-list")

    // MARK: - Plugin Properties

    nonisolated static let emoji = "💬"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false
    static let id: String = "ConversationList"
    static let displayName: String = String(localized: "Conversation List", table: "ConversationList")
    static let description: String = String(localized: "Show all conversation history", table: "ConversationList")
    static let iconName: String = "message.fill"
    static let isConfigurable: Bool = false
    static var order: Int { 76 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = ConversationListPlugin()

    init() {}

    // MARK: - Toolbar Views

    /// 工具栏右侧：会话列表按钮
    @MainActor
    func addToolBarTrailingView() -> AnyView? {
        AnyView(ConversationListPopoverButton())
    }
}
