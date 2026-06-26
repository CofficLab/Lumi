import Foundation
import LumiChatKit
import LumiCoreKit
import Testing
@testable import ModelSelectorPlugin

@MainActor
@Test func chatSectionToolbarItemsRequireVisibleChatSection() {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ModelSelectorPluginTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let chatService = ChatService(configuration: .coreDatabase(directory: directory))

    let hiddenContext = LumiPluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat",
        chatSection: .wide,
        isChatSectionVisible: false,
        dependencies: LumiPluginDependencies { dependencies in
            dependencies.register(LumiChatServicing.self, chatService)
        }
    )
    #expect(ModelSelectorPlugin.chatSectionToolbarItems(context: hiddenContext).isEmpty)

    let shownContext = LumiPluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat",
        chatSection: .wide,
        isChatSectionVisible: true,
        dependencies: LumiPluginDependencies { dependencies in
            dependencies.register(LumiChatServicing.self, chatService)
        }
    )
    #expect(ModelSelectorPlugin.chatSectionToolbarItems(context: shownContext).count == 1)
    #expect(ModelSelectorPlugin.chatSectionToolbarItems(context: shownContext).first?.placement == .leading)
}

@MainActor
@Test func chatSectionToolbarItemsRequireChatService() {
    let context = LumiPluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat",
        chatSection: .wide,
        isChatSectionVisible: true
    )
    #expect(ModelSelectorPlugin.chatSectionToolbarItems(context: context).isEmpty)
}

@MainActor
@Test func chatSectionToolbarBarItemsRequireVisibleChatSection() {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ModelSelectorPluginTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let chatService = ChatService(configuration: .coreDatabase(directory: directory))

    let hiddenContext = LumiPluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat",
        chatSection: .wide,
        isChatSectionVisible: false,
        dependencies: LumiPluginDependencies { dependencies in
            dependencies.register(LumiChatServicing.self, chatService)
        }
    )
    #expect(ModelSelectorPlugin.chatSectionToolbarBarItems(context: hiddenContext).isEmpty)

    let shownContext = LumiPluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat",
        chatSection: .wide,
        isChatSectionVisible: true,
        dependencies: LumiPluginDependencies { dependencies in
            dependencies.register(LumiChatServicing.self, chatService)
        }
    )
    #expect(ModelSelectorPlugin.chatSectionToolbarBarItems(context: shownContext).count == 1)
    #expect(ModelSelectorPlugin.chatSectionToolbarBarItems(context: shownContext).first?.id == "com.coffic.lumi.plugin.model-selector.tps")
}

@MainActor
@Test func switchModelToolUpdatesConversationPreference() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ModelSelectorPluginTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let chatService = ChatService(configuration: .coreDatabase(directory: directory))
    let provider = MockLLMProvider()
    chatService.registerProviders([provider])

    let conversationID = chatService.createConversation(title: "Test")
    chatService.selectConversation(id: conversationID)

    let tool = SwitchModelTool(chatService: chatService)
    let result = try await tool.execute(
        arguments: [
            "providerId": .string("mock"),
            "modelId": .string("mock-model-b")
        ],
        context: LumiToolExecutionContext(
            conversationID: conversationID,
            toolCallID: "tool-call",
            toolName: SwitchModelTool.info.id
        )
    )

    #expect(result.contains("✅"))
    #expect(chatService.providerID(for: conversationID) == "mock")
    #expect(chatService.modelName(for: conversationID) == "mock-model-b")
    #expect(chatService.routingMode == .manual)
}

private struct MockLLMProvider: LumiLLMProvider {
    static let info = LumiLLMProviderInfo(
        id: "mock",
        displayName: "Mock",
        description: "Mock provider",
        defaultModel: "mock-model-a",
        availableModels: ["mock-model-a", "mock-model-b"],
        websiteURL: URL(string: "https://example.com")!
    )

    func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        LumiChatMessage(conversationID: UUID(), role: .assistant, content: "ok")
    }

    func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        .available
    }
}
