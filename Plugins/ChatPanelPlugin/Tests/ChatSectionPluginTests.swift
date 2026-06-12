import Foundation
import LumiChatKit
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

    #expect(ChatMessagesSectionPlugin.chatSectionItems(context: context).isEmpty)
    #expect(ChatPendingSectionPlugin.chatSectionItems(context: context).isEmpty)
    #expect(ChatAttachmentSectionPlugin.chatSectionItems(context: context).isEmpty)
    #expect(ChatComposerSectionPlugin.chatSectionItems(context: context).isEmpty)
}

@MainActor
@Test func chatSectionPluginsRequireCoordinatorWhenVisible() {
    let context = LumiPluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat",
        chatSection: .wide
    )

    #expect(ChatMessagesSectionPlugin.chatSectionItems(context: context).isEmpty)
    #expect(ChatComposerSectionPlugin.chatSectionItems(context: context).isEmpty)
}

@MainActor
@Test func chatSectionPluginsContributeItemsWithCoordinator() {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ChatSectionPluginTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let chatService = ChatService(configuration: .coreDatabase(directory: directory))
    let coordinator = ChatSectionCoordinator(chatService: chatService)
    let context = LumiPluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat",
        chatSection: .wide,
        dependencies: LumiPluginDependencies { dependencies in
            dependencies.register(ChatSectionCoordinator.self, coordinator)
        }
    )

    #expect(ChatMessagesSectionPlugin.chatSectionItems(context: context).count == 1)
    #expect(ChatPendingSectionPlugin.chatSectionItems(context: context).count == 1)
    #expect(ChatAttachmentSectionPlugin.chatSectionItems(context: context).count == 1)
    #expect(ChatComposerSectionPlugin.chatSectionItems(context: context).count == 1)
    #expect(ChatComposerSectionPlugin.chatSectionItems(context: context).first?.placement == .bottomFixed)
}

@MainActor
@Test func coordinatorForwardsChatServiceSelectionChanges() {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ChatSectionCoordinatorTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let chatService = ChatService(configuration: .coreDatabase(directory: directory))
    let coordinator = ChatSectionCoordinator(chatService: chatService)
    let firstID = chatService.createConversation(title: "First")
    let secondID = chatService.createConversation(title: "Second")

    chatService.selectConversation(id: firstID)
    #expect(coordinator.selectedConversationID == firstID)

    chatService.selectConversation(id: secondID)
    #expect(coordinator.selectedConversationID == secondID)
    #expect(coordinator.displayedMessages(for: secondID) == coordinator.displayedMessages(for: coordinator.selectedConversationID!))
}
