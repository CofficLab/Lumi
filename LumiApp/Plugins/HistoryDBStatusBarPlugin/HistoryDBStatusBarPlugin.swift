import MagicKit
import SwiftUI
import Foundation

/// 历史数据库状态栏插件：在 Agent 模式底部状态栏显示数据库图标，点击后以表格形式浏览消息/对话数据
actor HistoryDBStatusBarPlugin: SuperPlugin {
    nonisolated static let emoji = "🗄️"
    nonisolated static let enable: Bool = true
    nonisolated static let verbose: Bool = false

    static let id: String = "HistoryDBStatusBar"
    static let navigationId: String? = nil
    static let displayName: String = String(localized: "History Database Browser", table: "HistoryDBStatusBar")
    static let description: String = String(localized: "Browse message and conversation history in status bar popover", table: "HistoryDBStatusBar")
    static let iconName: String = "tablecells"
    static let isConfigurable: Bool = false
    static var order: Int { 98 }

    nonisolated var instanceLabel: String { Self.id }
    static let shared = HistoryDBStatusBarPlugin()

    @MainActor
    func addStatusBarTrailingView(activeIcon: String?) -> AnyView? {
        AnyView(HistoryDBStatusBarView())
    }
}
