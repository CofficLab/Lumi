import LumiCoreAgentTool
import LumiCoreChat
import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public final class ChatPanelPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.chat-panel"
    public let name = "Chat"
    public let order = 78
    public let policy: LumiPluginPolicy = .alwaysOn

    public init() {}

    public func register(kernel: LumiKernel) throws {
        guard let storage = kernel.storage else {
            throw ChatPanelError.storageServiceMissing
        }

        let coreDataDirectory = storage.coreDataDirectory()
        let agentToolComponent = AgentToolComponent()
        let chatService = try LumiCoreChat.ChatService(
            configuration: .coreDatabase(directory: coreDataDirectory),
            agentToolComponent: agentToolComponent
        )

        let coordinator = ChatSectionCoordinator(chatService: chatService)
        kernel.registerService(ChatSectionCoordinator.self, coordinator)
    }

    public func boot(kernel: LumiKernel) async throws {}

    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] {
        [
            ViewContainerItem(
                id: id,
                title: name,
                systemImage: "bubble.left.and.bubble.right.fill",
                chatSection: .narrow,
                showsRail: true,
                showsPanelChrome: true
            ) {
                ChatPanelContentView()
            }
        ]
    }

    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] {
        guard let coordinator = kernel.resolveService(ChatSectionCoordinator.self) else {
            return []
        }

        return [
            StatusBarItem(
                id: "\(id).timeline",
                title: "Conversation Timeline",
                systemImage: "timeline.selection",
                placement: .trailing,
                statusBarView: {
                    ChatTimelineStatusBarView(chatService: coordinator.chatService)
                }
            )
        ]
    }

    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] {
        [
            OnboardingPageItem(id: "\(id).onboarding") {
                PluginOnboardingPageView(
                    icon: "bubble.left.and.bubble.right.fill",
                    displayName: self.name,
                    description: "Chat surface with conversation rail",
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
            }
        ]
    }
}

enum ChatPanelError: Error {
    case storageServiceMissing
}
