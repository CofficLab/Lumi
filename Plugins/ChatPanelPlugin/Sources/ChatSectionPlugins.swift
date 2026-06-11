import LumiCoreKit
import LumiUI
import SwiftUI

public enum ChatMessagesSectionPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "text.bubble.fill"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.chat-messages-section",
        displayName: String(localized: "Chat Messages", bundle: .module),
        description: String(localized: "Agent chat messages timeline in the right ChatSection.", bundle: .module),
        order: 82
    )

    @MainActor
    public static func chatSectionItems(context: LumiPluginContext) -> [LumiChatSectionItem] {
        guard context.showsChatSection,
              let coordinator = context.resolve(ChatSectionCoordinator.self)
        else {
            return []
        }

        return [
            LumiChatSectionItem(id: info.id, order: info.order) {
                ChatMessagesSectionView(coordinator: coordinator)
            }
        ]
    }
}

public enum ChatPendingSectionPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "clock"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.chat-pending-section",
        displayName: String(localized: "Chat Pending Messages", bundle: .module),
        description: String(localized: "Queued chat messages above the composer.", bundle: .module),
        order: 95
    )

    @MainActor
    public static func chatSectionItems(context: LumiPluginContext) -> [LumiChatSectionItem] {
        guard context.showsChatSection,
              let coordinator = context.resolve(ChatSectionCoordinator.self)
        else {
            return []
        }

        return [
            LumiChatSectionItem(id: info.id, order: info.order) {
                ChatPendingSectionView(coordinator: coordinator)
            }
        ]
    }
}

public enum ChatAttachmentSectionPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "paperclip"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.chat-attachment-section",
        displayName: String(localized: "Chat Attachment", bundle: .module),
        description: String(localized: "Pending chat attachments and sidebar drop handling.", bundle: .module),
        order: 94
    )

    @MainActor
    public static func chatSectionItems(context: LumiPluginContext) -> [LumiChatSectionItem] {
        guard context.showsChatSection,
              let coordinator = context.resolve(ChatSectionCoordinator.self)
        else {
            return []
        }

        return [
            LumiChatSectionItem(id: info.id, order: info.order) {
                ChatAttachmentSectionView(coordinator: coordinator)
            }
        ]
    }

    @MainActor
    public static func chatSectionRootWrapper(context: LumiPluginContext, content: AnyView) -> AnyView {
        guard context.showsChatSection,
              let coordinator = context.resolve(ChatSectionCoordinator.self)
        else {
            return content
        }

        return AnyView(
            ChatSectionDropRootView(coordinator: coordinator, content: content)
        )
    }
}

public enum ChatComposerSectionPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "keyboard"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.chat-composer-section",
        displayName: String(localized: "Chat Composer", bundle: .module),
        description: String(localized: "Chat input area with editor and command suggestions.", bundle: .module),
        order: 96
    )

    @MainActor
    public static func chatSectionItems(context: LumiPluginContext) -> [LumiChatSectionItem] {
        guard context.showsChatSection,
              let coordinator = context.resolve(ChatSectionCoordinator.self)
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
