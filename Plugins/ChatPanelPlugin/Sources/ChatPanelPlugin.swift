import LumiChatKit
import LumiCoreKit
import LumiUI
import SwiftUI

public enum ChatPanelPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: ChatPanelSection.id,
        displayName: LumiPluginLocalization.string("Chat", bundle: .module),
        description: LumiPluginLocalization.string("Chat surface with conversation rail", bundle: .module),
        order: 78,
        category: .agent,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "bubble.left.and.bubble.right.fill",
    )

    @MainActor
    public static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        guard context.isChatSectionVisible,
              let chatService = context.resolve(LumiChatServicing.self) as? ChatService
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

    @MainActor
    public static func onboardingPages(context: LumiPluginContext) -> [AnyView] {
        [
            AnyView(
                PluginOnboardingPageView(
                    icon: iconName,
                    displayName: info.displayName,
                    description: info.description,
                    features: [
                        .init(
                            icon: "bubble.left.and.bubble.right",
                            title: LumiPluginLocalization.string("Conversations", bundle: .module),
                            description: LumiPluginLocalization.string("Chat with local and cloud LLMs", bundle: .module)
                        ),
                        .init(
                            icon: "rectangle.3.group",
                            title: LumiPluginLocalization.string("Parallel sessions", bundle: .module),
                            description: LumiPluginLocalization.string("Run multiple independent tasks side by side", bundle: .module)
                        ),
                    ],
                    tip: LumiPluginLocalization.string("Pick Chat from the sidebar to start a new conversation.", bundle: .module)
                )
            )
        ]
    }
}

