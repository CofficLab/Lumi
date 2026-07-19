import LumiCoreKit
import LumiCoreKit
import SwiftUI

public enum RequestLogPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.request-log",
        displayName: LumiPluginLocalization.string("PluginName", bundle: .module),
        description: LumiPluginLocalization.string("PluginDescription", bundle: .module),
        order: 100,
        category: .agent,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "list.clipboard.fill",
    )

    @MainActor
    public static func sendMiddlewares(context: any LumiCoreAccessing) -> [any LumiSendMiddleware] {
        [RequestLogChatMiddleware()]
    }

    @MainActor
    public static func statusBarItems(context: any LumiCoreAccessing) -> [LumiStatusBarItem] {
        guard context.isChatSectionVisible,
              context.resolve((any LumiChatServicing).self) != nil
        else {
            return []
        }

        return [
            LumiStatusBarItem(
                id: "\(info.id).summary",
                title: LumiPluginLocalization.string("Request Log", bundle: .module),
                systemImage: iconName,
                placement: .trailing,
                statusBarView: {
                    RequestLogSummaryStatusBarView()
                }
            )
        ]
    }
}
