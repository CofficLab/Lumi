import Foundation
import LumiCoreKit
import LumiCoreKit
import Testing
@testable import ChatPanelPlugin

@MainActor
@Test func chatSectionPluginsReturnEmptyWhenChatSectionHidden() {
    let context = LumiPluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat",
        chatSection: .none
    )

    #expect(ChatPendingSectionPlugin.chatSectionItems(lumiCore: context).isEmpty)
    #expect(ChatAttachmentSectionPlugin.chatSectionItems(lumiCore: context).isEmpty)
    #expect(ChatComposerSectionPlugin.chatSectionItems(lumiCore: context).isEmpty)
}

@MainActor
@Test func chatSectionPluginsRequireCoordinatorWhenVisible() {
    let context = LumiPluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat",
        chatSection: .wide
    )

    #expect(ChatComposerSectionPlugin.chatSectionItems(lumiCore: context).isEmpty)
}

@MainActor
@Test func chatSectionPluginsContributeItemsWithCoordinator() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ChatSectionPluginTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let chatService = try ChatService(configuration: .coreDatabase(directory: directory), agentToolComponent: AgentToolComponent())
    let coordinator = ChatSectionCoordinator(chatService: chatService)
    let context = LumiPluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat",
        chatSection: .wide,
        dependencies: LumiPluginDependencies { dependencies in
            dependencies.register(ChatSectionCoordinator.self, coordinator)
        }
    )

    #expect(ChatPendingSectionPlugin.chatSectionItems(lumiCore: context).count == 1)
    #expect(ChatAttachmentSectionPlugin.chatSectionItems(lumiCore: context).count == 1)
    #expect(ChatComposerSectionPlugin.chatSectionItems(lumiCore: context).count == 1)
    #expect(ChatComposerSectionPlugin.chatSectionItems(lumiCore: context).first?.placement == .bottomFixed)
}

@MainActor
@Test func coordinatorForwardsChatServiceSelectionChanges() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ChatSectionCoordinatorTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let chatService = try ChatService(configuration: .coreDatabase(directory: directory), agentToolComponent: AgentToolComponent())
    let coordinator = ChatSectionCoordinator(chatService: chatService)
    let firstID = chatService.createConversation(title: "First")
    let secondID = chatService.createConversation(title: "Second")

    chatService.selectConversation(id: firstID)
    #expect(coordinator.selectedConversationID == firstID)

    chatService.selectConversation(id: secondID)
    #expect(coordinator.selectedConversationID == secondID)
    #expect(coordinator.displayedMessages(for: secondID) == coordinator.displayedMessages(for: coordinator.selectedConversationID!))
}
