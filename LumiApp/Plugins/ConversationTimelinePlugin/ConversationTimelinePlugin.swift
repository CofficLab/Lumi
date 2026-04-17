import MagicKit
import SwiftUI
import Foundation
import os

/// 对话时间线状态栏插件：在状态栏显示对话图标，点击显示当前对话的消息历史时间线
actor ConversationTimelinePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-timeline")
    nonisolated static let emoji = "📅"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false

    static let id: String = "ConversationTimeline"
    static let navigationId: String? = nil
    static let displayName: String = String(localized: "Conversation Timeline", table: "ConversationTimeline")
    static let description: String = String(localized: "Display conversation message timeline in status bar", table: "ConversationTimeline")
    static let iconName: String = "timeline.selection"
    static let isConfigurable: Bool = false
    static var order: Int { 97 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = ConversationTimelinePlugin()

    // MARK: - UI Contributions

    /// 添加状态栏尾部视图
    @MainActor func addStatusBarTrailingView() -> AnyView? {
        return AnyView(ConversationTimelineView())
    }
}
