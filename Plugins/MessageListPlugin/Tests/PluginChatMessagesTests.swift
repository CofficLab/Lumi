import Foundation
import LumiCoreKit
import LumiCoreKit
import Testing
@testable import MessageListPlugin

@MainActor
@Test func chatMessagesSectionPluginReturnsEmptyWhenChatSectionHidden() {
    let context = LumiPluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat",
        chatSection: .none
    )

    #expect(ChatMessagesSectionPlugin.chatSectionItems(context: context).isEmpty)
}

@MainActor
@Test func chatMessagesSectionPluginRequiresCoordinatorWhenVisible() {
    let context = LumiPluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat",
        chatSection: .wide
    )

    #expect(ChatMessagesSectionPlugin.chatSectionItems(context: context).isEmpty)
}

@MainActor
@Test func chatMessagesSectionPluginContributesItemWithCoordinator() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("MessageListPluginTests-\(UUID().uuidString)", isDirectory: true)
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

    #expect(ChatMessagesSectionPlugin.chatSectionItems(context: context).count == 1)
    #expect(ChatMessagesSectionPlugin.chatSectionItems(context: context).first?.fillsRemainingHeight == true)
}
