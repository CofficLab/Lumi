import Foundation
import SwiftUI
import OSLog
import MagicKit

/// Conversation List Plugin: 显示对话历史列表
actor ConversationListPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    /// Log identifier
    nonisolated static let emoji = "💬"

    /// Whether to enable this plugin
    static let enable = true

    /// Whether to enable verbose log output
    nonisolated static let verbose = true

    /// Plugin unique identifier
    static let id: String = "ConversationList"

    /// Plugin display name
    static let displayName: String = "对话列表"

    /// Plugin functional description
    static let description: String = "显示所有对话历史记录"

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
    @MainActor func addSidebarView() -> AnyView? {
        if Self.verbose {
            os_log("\(self.t) 提供 ConversationListView")
        }
        return AnyView(ConversationListView())
    }
}
