import Foundation
import MagicKit
import os
import SwiftUI

/// Conversation List Plugin: 显示对话历史列表
actor ConversationListPlugin: SuperPlugin, SuperLog {
    /// 插件专用 Logger
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-list")

    // MARK: - Plugin Properties

    /// Log identifier
    nonisolated static let emoji = "💬"

    /// Whether to enable this plugin
    nonisolated static let enable: Bool = true
    /// Whether to enable verbose log output
    nonisolated static let verbose: Bool = false
    /// Plugin unique identifier
    static let id: String = "ConversationList"

    /// Plugin display name
    static let displayName: String = String(localized: "Conversation List", table: "ConversationList")

    /// Plugin functional description
    static let description: String = String(localized: "Show all conversation history", table: "ConversationList")

    /// Plugin icon name
    static let iconName: String = "message.fill"

    /// Whether it is configurable
    static let isConfigurable: Bool = false

    /// Registration order
    static var order: Int { 76 }

    // MARK: - Instance

    /// Plugin instance label (used to identify unique instances)
    nonisolated var instanceLabel: String {
        Self.id
    }

    /// Plugin singleton instance
    static let shared = ConversationListPlugin()

    /// Initialization method
    init() {}

    // MARK: - UI Contributions

    /// Add sidebar view for Agent mode - 显示对话列表
    /// - Returns: ConversationListView to be added to the sidebar
    @MainActor func addPanelView() -> AnyView? {
        if Self.verbose {
            Self.logger.info("\(self.t) 提供 ConversationListView")
        }
        return AnyView(ConversationListView())
    }
}