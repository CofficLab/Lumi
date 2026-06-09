import LumiChatKit
import LumiCoreKit
import SwiftUI

public enum RequestLogPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.request-log",
        displayName: String(localized: "PluginName", bundle: .module),
        description: String(localized: "PluginDescription", bundle: .module),
        order: 100
    )
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "doc.text.magnifyingglass"

    @MainActor
    public static func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware] {
        [RequestLogChatMiddleware()]
    }

    @MainActor
    public static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        guard context.activeSectionID == LumiChatPanelSection.id,
              context.resolve((any LumiChatServicing).self) != nil
        else {
            return []
        }

        return [
            LumiStatusBarItem(
                id: "\(info.id).summary",
                title: String(localized: "Request Log", bundle: .module),
                systemImage: iconName,
                placement: .trailing,
                statusBarView: {
                    RequestLogSummaryStatusBarView()
                }
            )
        ]
    }
}
