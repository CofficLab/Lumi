import LumiCoreKit
import SwiftUI

/// 详细级别切换插件：在 Chat 工具栏提供简洁 / 标准 / 详细回复风格选择。
public enum VerbosityPlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.verbosity",
        displayName: LumiPluginLocalization.string("Verbosity", bundle: .module),
        description: LumiPluginLocalization.string("Switch between Brief, Normal, and Detailed response styles", bundle: .module),
        order: 85,
        category: .agent,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "text.alignleft",
    )

    @MainActor
    public static func chatSectionToolbarBarItems(context: LumiPluginContext) -> [LumiChatSectionToolbarBarItem] {
        guard context.showsChatSection,
              let chatService = context.resolve(LumiChatServicing.self)
        else {
            return []
        }

        return [
            LumiChatSectionToolbarBarItem(id: info.id, order: info.order) {
                VerbosityToolbarView(chatService: chatService)
            }
        ]
    }
}
