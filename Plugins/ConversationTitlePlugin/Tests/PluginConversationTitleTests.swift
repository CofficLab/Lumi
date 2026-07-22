import Foundation
import LumiKernel
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
        lumiCore: LumiPluginContext(activeSectionID: "chat", activeSectionTitle: "Chat")
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
    let tools = ConversationTitlePlugin.agentTools(lumiCore: context)

    #expect(tools.map(\.name).contains("update_conversation_title"))
}
