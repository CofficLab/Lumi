import SwiftUI
import LumiCoreKit
import Foundation

/// 历史数据库插件：在 Agent 模式底部状态栏显示历史入口，点击后以 Tab 形式浏览消息/对话历史
public actor HistoryDBStatusBarPlugin: SuperPlugin {
    public nonisolated static let emoji = "🗄️"
    public static var category: PluginCategory { .general }
    public nonisolated static let verbose: Bool = false
    public nonisolated static let policy: PluginPolicy = .alwaysOn

    public static let id: String = "HistoryDBStatusBar"
    public static let navigationId: String? = nil
    public static let displayName: String = String(localized: "History Database Browser", bundle: .module)
    public static let description: String = String(localized: "Browse message and conversation history in status bar popover", bundle: .module)
    public static let iconName: String = "tablecells"
    public static var order: Int { 98 }

    public nonisolated var instanceLabel: String { Self.id }
    public static let shared = HistoryDBStatusBarPlugin()

    @MainActor
    public func addStatusBarTrailingView(context: PluginContext) -> AnyView? {
        guard context.showChat.isVisible else { return nil }
        return AnyView(StatusBarView(historyService: context.historyService))
    }
}
