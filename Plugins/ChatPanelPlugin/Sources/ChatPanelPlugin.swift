import LumiChatKit
import LumiCoreKit
import LumiUI
import SwiftUI

public enum ChatPanelPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "bubble.left.and.bubble.right.fill"
    public static let info = LumiPluginInfo(
        id: ChatPanelSection.id,
        displayName: String(localized: "Chat", bundle: .module),
        description: String(localized: "Chat surface with conversation rail", bundle: .module),
        order: 78
    )

    @MainActor
    public static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        guard context.activeSectionID == info.id,
              let chatService = context.resolve(LumiChatServicing.self)
        else {
            return []
        }

        return [
            LumiStatusBarItem(
                id: "\(info.id).timeline",
                title: "Conversation Timeline",
                systemImage: "timeline.selection",
                placement: .trailing,
                statusBarView: {
                    ChatTimelineStatusBarView(chatService: chatService)
                }
            ),
            LumiStatusBarItem(
                id: "\(info.id).tools",
                title: "Available Tools",
                systemImage: "wrench.and.screwdriver",
                placement: .trailing,
                statusBarView: {
                    ChatAvailableToolsStatusBarView(chatService: chatService)
                }
            )
        ]
    }

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName,
                chatSection: .wide,
                showsRail: true
            ) {
                ChatPanelEmptyView()
            }
        ]
    }
}

