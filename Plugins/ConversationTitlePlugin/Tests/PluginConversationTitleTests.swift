import Foundation
import LumiChatKit
import LumiCoreKit
import Testing
@testable import ConversationTitlePlugin

@Test func packageLoads() async throws {
    #expect(ConversationTitlePlugin.info.id == "com.coffic.lumi.plugin.conversation-title")
}

@Test func pluginPolicyIsAlwaysOn() {
    #expect(ConversationTitlePlugin.policy == .alwaysOn)
    #expect(ConversationTitlePlugin.policy.isConfigurable == false)
}

@MainActor
@Test func pluginRegistersTitleHintMiddleware() {
    let middlewares = ConversationTitlePlugin.sendMiddlewares(
        context: LumiPluginContext(activeSectionID: "chat", activeSectionTitle: "Chat")
    )

    #expect(middlewares.count == 1)
}

@MainActor
@Test func pluginRegistersTitleToolWhenChatServiceExists() throws {
    let databaseDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ConversationTitlePluginTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: databaseDirectory) }

    let chatService = try ChatService(
        configuration: .coreDatabase(directory: databaseDirectory)
    )
    let context = LumiPluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat",
        dependencies: LumiPluginDependencies { dependencies in
            dependencies.register((any LumiChatServicing).self, chatService)
        }
    )
    let tools = ConversationTitlePlugin.agentTools(context: context)

    #expect(tools.map(\.name).contains("update_conversation_title"))
}

@MainActor
@Test func pluginContributesTitleHeaderWhenChatSectionVisible() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ConversationTitlePluginTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let chatService = try ChatService(configuration: .coreDatabase(directory: directory))
    let coordinator = ChatSectionCoordinator(chatService: chatService)
    let hidden = LumiPluginContext(
        activeSectionID: "editor",
        activeSectionTitle: "Editor",
        chatSection: .wide,
        isChatSectionVisible: false,
        dependencies: LumiPluginDependencies {
            $0.register(ChatSectionCoordinator.self, coordinator)
        }
    )
    let visible = LumiPluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat",
        chatSection: .wide,
        isChatSectionVisible: true,
        dependencies: LumiPluginDependencies {
            $0.register(ChatSectionCoordinator.self, coordinator)
        }
    )

    #expect(ConversationTitlePlugin.chatSectionItems(context: hidden).isEmpty)
    #expect(ConversationTitlePlugin.chatSectionItems(context: visible).count == 1)
    #expect(ConversationTitlePlugin.chatSectionItems(context: visible).first?.order == 81)
    #expect(ConversationTitlePlugin.chatSectionItems(context: visible).first?.fillsRemainingHeight == false)
}
