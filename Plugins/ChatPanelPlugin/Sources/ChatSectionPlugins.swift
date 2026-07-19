import LumiCoreKit
import SwiftUI

public enum ChatPendingSectionPlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.chat-pending-section",
        displayName: LumiPluginLocalization.string("Chat Pending Messages", bundle: .module),
        description: LumiPluginLocalization.string("Queued chat messages above the composer.", bundle: .module),
        order: 95,
        category: .agent,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "clock"
    )

    @MainActor
    public static func chatSectionItems(lumiCore: any LumiCoreAccessing) -> [LumiChatSectionItem] {
        // Pending messages are now rendered inline inside ChatComposerSectionView
        return []
    }
}

public enum ChatAttachmentSectionPlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.chat-attachment-section",
        displayName: LumiPluginLocalization.string("Chat Attachment", bundle: .module),
        description: LumiPluginLocalization.string("Pending chat attachments above the composer.", bundle: .module),
        order: 94
    )

    @MainActor
    public static func chatSectionItems(lumiCore: any LumiCoreAccessing) -> [LumiChatSectionItem] {
        guard lumiCore.layoutComponent.state.chatSectionVisible,
              let coordinator = lumiCore.resolveService((any ChatSectionCoordinator).self)
        else {
            return []
        }

        return [
            LumiChatSectionItem(id: info.id, order: info.order) {
                ChatAttachmentSectionView(coordinator: coordinator)
            }
        ]
    }

}

public enum ChatComposerSectionPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.chat-composer-section",
        displayName: LumiPluginLocalization.string("Chat Composer", bundle: .module),
        description: LumiPluginLocalization.string("Chat input area with editor and command suggestions.", bundle: .module),
        order: 96,
        category: .agent,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "keyboard"
    )

    @MainActor
    public static func chatSectionItems(lumiCore: any LumiCoreAccessing) -> [LumiChatSectionItem] {
        guard lumiCore.layoutComponent.state.chatSectionVisible,
              let coordinator = lumiCore.resolveService((any ChatSectionCoordinator).self)
        else {
            return []
        }

        return [
            LumiChatSectionItem(id: info.id, order: info.order, placement: .bottomFixed) {
                ChatComposerSectionView(coordinator: coordinator)
            }
        ]
    }
}
