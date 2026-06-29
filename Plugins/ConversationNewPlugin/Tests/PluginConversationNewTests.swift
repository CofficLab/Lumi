import Foundation
import Testing
import LumiCoreKit
@testable import ConversationNewPlugin

@Test func pluginPolicyIsAlwaysOn() {
    #expect(ConversationNewPlugin.policy == .alwaysOn)
    #expect(ConversationNewPlugin.policy.isConfigurable == false)
}

@Test func localStorePersistsDefaultAutomationLevel() throws {
    let databaseDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ConversationNewStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: databaseDirectory) }

    let store = LocalStore(databaseDirectory: databaseDirectory)
    store.saveDefaultAutomationLevel(.autonomous)

    let reloadedStore = LocalStore(databaseDirectory: databaseDirectory)
    #expect(reloadedStore.loadDefaultAutomationLevel() == .autonomous)
}

@MainActor
@Test func titleToolbarItemsRequireChatSectionAndService() {
    let hiddenChatContext = LumiPluginContext(
        activeSectionID: "editor",
        activeSectionTitle: "Editor",
        chatSection: .none
    )
    let visibleWithoutService = LumiPluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat",
        chatSection: .narrow
    )
    let chatService = MockChatService()
    var dependencies = LumiPluginDependencies()
    dependencies.register((any LumiChatServicing).self, chatService)
    let visibleWithService = LumiPluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat",
        chatSection: .narrow,
        dependencies: dependencies
    )

    #expect(ConversationNewPlugin.titleToolbarItems(context: hiddenChatContext).isEmpty)
    #expect(ConversationNewPlugin.titleToolbarItems(context: visibleWithoutService).isEmpty)
    #expect(ConversationNewPlugin.titleToolbarItems(context: visibleWithService).count == 1)
}

@MainActor
@Test func newChatUsesStoredAutomationLevel() {
    let databaseDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ConversationNewStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: databaseDirectory) }

    let store = LocalStore(databaseDirectory: databaseDirectory)
    store.saveDefaultAutomationLevel(.build)

    let chatService = MockChatService()
    chatService.currentAutomationLevel = .autonomous

    let button = NewChatButton(chatService: chatService)
    button.createConversation(using: store)

    #expect(chatService.createdAutomationLevels == [.build])
    #expect(chatService.createConversationCallCount == 1)
}

@MainActor
private final class MockChatService: LumiChatServicing {
    var conversations: [LumiConversationSummary] = []
    var selectedConversationID: UUID?
    var providerInfos: [LumiLLMProviderInfo] = []
    var selectedProviderID: String?
    var selectedModel: String?
    var messageRenderers: [LumiMessageRendererItem] = []
    var revision = 0
    var agentTools: [any LumiAgentTool] = []
    var pendingMessages: [LumiPendingMessage] = []
    var routingMode: LumiModelRoutingMode = .manual
    var pendingToolConfirmation: LumiPendingToolConfirmation?
    var currentAutomationLevel: LumiAutomationLevel = .chat
    var createConversationCallCount = 0
    var createdAutomationLevels: [LumiAutomationLevel] = []

    func isSending(for conversationID: UUID?) -> Bool { false }

    func createConversation(title: String?) -> UUID {
        createConversation(title: title, projectPath: nil, language: nil)
    }

    func createConversation(title: String?, projectPath: String?, language: LumiConversationLanguage?) -> UUID {
        createConversationCallCount += 1
        return UUID()
    }

    func selectConversation(id: UUID) {}
    func deleteConversation(id: UUID) {}
    func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool { false }
    func setConversationProjectPath(_ projectPath: String?, for conversationID: UUID) -> Bool { false }
    func selectProvider(id: String, model: String?) {}
    func selectProvider(id: String, model: String?, for conversationID: UUID?) {}
    func providerID(for conversationID: UUID?) -> String? { nil }
    func modelName(for conversationID: UUID?) -> String? { nil }
    func setRoutingMode(_ mode: LumiModelRoutingMode) {}
    func language(for conversationID: UUID?) -> LumiConversationLanguage { .english }
    func setLanguage(_ language: LumiConversationLanguage, for conversationID: UUID?) {}
    func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel { currentAutomationLevel }
    func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?) {
        createdAutomationLevels.append(automationLevel)
    }
    func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity { .standard }
    func setVerbosity(_ verbosity: LumiResponseVerbosity, for conversationID: UUID?) {}
    func registerToolService(_ toolService: (any LumiToolServicing)?) {}
    func renderer(for message: LumiChatMessage) -> LumiMessageRendererItem? { nil }
    func messages(for conversationID: UUID) -> [LumiChatMessage] { [] }
    func displayMessages(for conversationID: UUID) -> [LumiChatMessage] { [] }
    func transientStatusMessage(for conversationID: UUID) -> LumiChatMessage? { nil }
    func visibleMessages(for conversationID: UUID, limit: Int, beforeMessageID: UUID?) -> [LumiChatMessage] { [] }
    func hasEarlierMessages(for conversationID: UUID, beforeMessageID: UUID?) -> Bool { false }
    func enqueueText(_ text: String, in conversationID: UUID?) {}
    func enqueueText(_ text: String, imageAttachments: [LumiImageAttachment], in conversationID: UUID?) {}
    func continueTurn(in conversationID: UUID) {}
    func cancelSending(for conversationID: UUID?) {}
    func approvePendingTool() {}
    func rejectPendingTool() {}
    func removePendingMessage(id: UUID) {}
    func deleteMessage(id: UUID, in conversationID: UUID) {}
    func resendMessage(id: UUID, in conversationID: UUID) async {}
    func send(_ text: String, in conversationID: UUID?) async {}
    func generateEphemeralCompletion(messages: [LumiChatMessage], model: String, conversationID: UUID) async throws -> LumiChatMessage {
        LumiChatMessage(conversationID: conversationID, role: .assistant, content: "")
    }
    func conversationContextUsage(for conversationID: UUID) -> LumiConversationContextUsage {
        .init(currentTokens: 0, limit: 0)
    }
}
