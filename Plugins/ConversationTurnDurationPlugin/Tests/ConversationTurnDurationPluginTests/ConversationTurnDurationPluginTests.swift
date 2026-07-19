import Testing
@testable import ConversationTurnDurationPlugin
import LumiKernel
import Foundation

@Suite("ConversationTurnDurationPlugin Tests")
struct ConversationTurnDurationPluginTests {

    @Test("Plugin info is correctly configured")
    func pluginInfoConfiguration() {
        #expect(ConversationTurnDurationPlugin.info.id == "com.coffic.lumi.plugin.conversation-turn-duration")
        #expect(ConversationTurnDurationPlugin.info.order == 86)
        #expect(ConversationTurnDurationPlugin.info.category == .agent)
        #expect(ConversationTurnDurationPlugin.info.policy == .alwaysOn)
        #expect(ConversationTurnDurationPlugin.info.stage == .beta)
        #expect(ConversationTurnDurationPlugin.info.iconName == "clock")
    }

    @Test("Plugin has valid display name and description")
    func pluginHasValidDisplayName() {
        // The strings should be retrievable from the localization system
        #expect(!ConversationTurnDurationPlugin.info.displayName.isEmpty)
        #expect(!ConversationTurnDurationPlugin.info.description.isEmpty)
    }

    @MainActor
    @Test("Duration format handles zero seconds")
    func durationFormatZero() {
        let viewModel = createViewModel()
        #expect(viewModel.durationText == "--:--")
        #expect(viewModel.isRunning == false)
    }

    @MainActor
    @Test("Duration format handles time intervals")
    func durationFormatting() {
        let viewModel = createViewModel()
        
        // Test less than 1 minute (30 seconds ago)
        viewModel.turnStartTime = Date().addingTimeInterval(-30)
        viewModel.updateDuration()
        #expect(viewModel.durationText.contains(":"))
        #expect(viewModel.durationText.hasPrefix("0:"))
        
        // Test more than 1 minute (90 seconds ago = 1:30)
        viewModel.turnStartTime = Date().addingTimeInterval(-90)
        viewModel.updateDuration()
        #expect(viewModel.durationText == "1:30")
        
        // Test more than 1 hour (3661 seconds ago = 1:01:01)
        viewModel.turnStartTime = Date().addingTimeInterval(-3661)
        viewModel.updateDuration()
        #expect(viewModel.durationText == "1:01:01")
    }

    // Helper to create ViewModel for testing
    @MainActor private func createViewModel() -> TurnDurationViewModel {
        let mockService = MockChatService()
        return TurnDurationViewModel(chatService: mockService)
    }
}

// MARK: - Mock Implementations

@MainActor
private final class MockChatService: ObservableObject, LumiChatServicing {
    var conversations: [LumiConversationSummary] = []
    @Published var selectedConversationID: UUID?
    var providerInfos: [LumiLLMProviderInfo] = []
    var selectedProviderID: String?
    var selectedModel: String?
    var messageRenderers: [LumiMessageRendererItem] = []
    @Published var revision: Int = 0
    var agentTools: [any LumiAgentTool] = []
    var pendingMessages: [LumiPendingMessage] = []
    var routingMode: LumiModelRoutingMode = .manual
    var pendingToolConfirmation: LumiPendingToolConfirmation?
    
    var isSendingFlag: Bool = false
    var messagesByID: [UUID: [LumiChatMessage]] = [:]
    
    func isSending(for conversationID: UUID?) -> Bool {
        return isSendingFlag
    }
    
    func createConversation(title: String?) -> UUID { UUID() }
    func createConversation(title: String?, projectPath: String?, language: LumiConversationLanguage?) -> UUID { UUID() }
    func selectConversation(id: UUID) {}
    func deleteConversation(id: UUID) {}
    func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool { false }
    func setConversationProjectPath(_ projectPath: String?, for conversationID: UUID) -> Bool { false }
    func selectProvider(id: String, model: String?) {}
    func selectProvider(id: String, model: String?, for conversationID: UUID?) {}
    func providerID(for conversationID: UUID?) -> String? { nil }
    func provider(forID id: String) -> (any LumiLLMProvider)? { nil }
    func modelName(for conversationID: UUID?) -> String? { nil }
    func setRoutingMode(_ mode: LumiModelRoutingMode) {}
    func language(for conversationID: UUID?) -> LumiConversationLanguage { .english }
    func setLanguage(_ language: LumiConversationLanguage, for conversationID: UUID?) {}
    func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel { .chat }
    func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?) {}
    func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity { .standard }
    func setVerbosity(_ verbosity: LumiResponseVerbosity, for conversationID: UUID?) {}
    func registerToolService(_ toolService: (any LumiToolServicing)?) {}
    func renderer(for message: LumiChatMessage) -> LumiMessageRendererItem? { nil }
    
    func messages(for conversationID: UUID) -> [LumiChatMessage] {
        return messagesByID[conversationID] ?? []
    }
    
    func displayMessages(for conversationID: UUID) -> [LumiChatMessage] { messages(for: conversationID) }
    func transientStatusMessage(for conversationID: UUID) -> LumiChatMessage? { nil }
    func visibleMessages(for conversationID: UUID, limit: Int, beforeMessageID: UUID?) -> [LumiChatMessage] { messages(for: conversationID) }
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
        throw NSError(domain: "Mock", code: -1)
    }
    func conversationContextUsage(for conversationID: UUID) -> LumiConversationContextUsage {
        LumiConversationContextUsage(currentTokens: 0, limit: 0)
    }
}
