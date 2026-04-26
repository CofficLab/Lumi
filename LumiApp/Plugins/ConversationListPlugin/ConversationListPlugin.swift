import Foundation
import MagicKit
import os
import SwiftUI

/// Conversation List Plugin: 对话历史列表
///
/// 注意：会话列表视图（ConversationListView）已整合到 EditorPlugin 的工具栏
/// Popover 入口（ConversationListPopoverButton）中。
/// 本插件保留用于维护会话列表相关的本地存储逻辑。
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
}
