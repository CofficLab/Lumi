import Foundation
import MagicKit
import OSLog
import SwiftUI

/// Agent Conversation Title Plugin: 负责生成会话标题
actor AgentConversationTitlePlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    /// Log identifier
    nonisolated static let emoji = "🏷️"

    /// Whether to enable this plugin
    static let enable = true

    /// Whether to enable verbose log output
    nonisolated static let verbose = false

    /// Plugin unique identifier
    static let id: String = "AgentConversationTitle"

    /// Plugin display name
    static let displayName: String = "会话标题生成"

    /// Plugin functional description
    static let description: String = "自动为会话生成描述性标题"

    /// Plugin icon name
    static let iconName: String = "tag.fill"

    /// Whether it is configurable
    static let isConfigurable: Bool = false

    /// Registration order
    static var order: Int { 75 }

    // MARK: - Instance

    /// Plugin instance label (used to identify unique instances)
    nonisolated var instanceLabel: String {
        Self.id
    }

    /// Plugin singleton instance
    static let shared = AgentConversationTitlePlugin()

    /// Initialization method
    init() {}

    // MARK: - UI Contributions

    /// Add root view wrapper for title generation
    @MainActor func addRootView<Content>(content: @escaping () -> Content) -> AnyView? where Content: View {
        if Self.verbose {
            os_log("\(self.t) 提供 AgentConversationTitleRootView")
        }
        return AnyView(
            AgentConversationTitleRootViewWrapper {
                content()
            }
        )
    }
}
