import LumiChatKit
import LumiCoreKit
import SwiftUI

/// 历史数据库浏览器：在聊天面板状态栏展示消息/对话列表。
public enum HistoryDBStatusBarPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.history-db-status-bar",
        displayName: String(localized: "History Database Browser", bundle: .module),
        description: String(localized: "Browse message and conversation history in status bar popover", bundle: .module),
        order: 98
    )
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .general
    public static let iconName = "tablecells"

    @MainActor
    public static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        guard context.activeSectionID == ChatPanelSection.id,
              let historyService = context.resolve((any HistoryQueryService).self)
        else {
            return []
        }

        return [
            LumiStatusBarItem(
                id: "\(info.id).browser",
                title: String(localized: "History Database Browser", bundle: .module),
                systemImage: iconName,
                placement: .trailing,
                statusBarView: {
                    StatusBarView(historyService: historyService)
                }
            ),
        ]
    }
}
