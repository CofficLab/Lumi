import SwiftUI
import SuperLogKit
import Foundation
import LumiCoreKit
import os

/// 对话时间线状态栏插件：在状态栏显示对话图标，点击显示当前对话的消息历史时间线
public actor ConversationTimelinePlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-timeline")
    public nonisolated static let emoji = "📅"
    public nonisolated static let policy: PluginPolicy = .alwaysOn
    public static var category: PluginCategory { .general }
    public nonisolated static let verbose: Bool = false

    public static let id: String = "ConversationTimeline"
    public static let navigationId: String? = nil
    public static let displayName: String = LumiPluginLocalization.string("Conversation Timeline", bundle: .module)
    public static let description: String = LumiPluginLocalization.string("Display conversation message timeline in status bar", bundle: .module)
    public static let iconName: String = "timeline.selection"
    public static var order: Int { 74 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = ConversationTimelinePlugin()

    // MARK: - UI Contributions

    /// 添加状态栏尾部视图
    ///
    /// 仅在当前 ViewContainer 支持 AI 聊天时显示，避免在非 AI 聊天场景（如 Git、Docker 等）显示不相关的对话时间线。
    @MainActor public func addStatusBarTrailingView(context: PluginContext) -> AnyView? {
        nil
    }
}
