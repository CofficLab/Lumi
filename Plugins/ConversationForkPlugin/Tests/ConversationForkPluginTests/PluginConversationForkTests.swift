import Foundation
import Testing
import LumiCoreKit
@testable import ConversationForkPlugin

// MARK: - Plugin registration

@Test func pluginPolicyIsAlwaysOn() {
    #expect(ConversationForkPlugin.policy == .alwaysOn)
    #expect(ConversationForkPlugin.policy.isConfigurable == false)
}

@Test func pluginOrderFollowsConversationNew() {
    // 紧跟 ConversationNewPlugin (order 60)，确保按钮相邻。
    #expect(ConversationForkPlugin.info.order == 61)
    #expect(ConversationForkPlugin.info.id == "com.coffic.lumi.plugin.conversation-fork")
}

@MainActor
@Test func toolbarItemsRequireChatSectionAndService() {
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

    #expect(ConversationForkPlugin.chatSectionToolbarItems(context: hiddenChatContext).isEmpty)
    #expect(ConversationForkPlugin.chatSectionToolbarItems(context: visibleWithoutService).isEmpty)
    #expect(ConversationForkPlugin.chatSectionToolbarItems(context: visibleWithService).count == 1)
}

// MARK: - Prompt templates

@Test func continuePromptWrapsSummaryWithDelimiters() {
    let prompt = ForkPromptTemplates.continuePrompt(summary: "Refactor X module")
    #expect(prompt.contains("Refactor X module"))
    #expect(prompt.contains("continuation"))
}

@Test func renderHistoryLabelsSpeakers() {
    let id = UUID()
    let messages = [
        LumiChatMessage(conversationID: id, role: .user, content: "hello"),
        LumiChatMessage(conversationID: id, role: .assistant, content: "hi there"),
    ]
    let rendered = ForkPromptTemplates.renderHistory(messages)
    #expect(rendered.contains("User: hello"))
    #expect(rendered.contains("Assistant: hi there"))
}

// MARK: - ConversationSummarizer

@MainActor
@Test func summarizeUsesModelWhenProviderAvailable() async {
    let id = UUID()
    let chatService = MockChatService()
    chatService.messagesByID[id] = [
        LumiChatMessage(conversationID: id, role: .user, content: "fix the bug"),
        LumiChatMessage(conversationID: id, role: .assistant, content: "working on it"),
    ]
    chatService.providerIDs[id] = "openai"
    chatService.modelNames[id] = "gpt-4o"
    chatService.ephemeralResponse = LumiChatMessage(
        conversationID: id,
        role: .assistant,
        content: "Model-generated summary"
    )

    let outcome = await ConversationSummarizer().summarize(conversationID: id, chatService: chatService)

    #expect(outcome.usedFallback == false)
    #expect(outcome.summary == "Model-generated summary")
    // 摘要请求：一条 system + 一条 user（引用历史）。
    #expect(chatService.ephemeralCallCount == 1)
    #expect(chatService.lastEphemeralMessages?.count == 2)
    #expect(chatService.lastEphemeralMessages?.first?.role == .system)
}

@MainActor
@Test func summarizeFallsBackWhenProviderMissing() async {
    let id = UUID()
    let chatService = MockChatService()
    chatService.messagesByID[id] = [
        LumiChatMessage(conversationID: id, role: .user, content: "do the thing"),
    ]
    // 没有 provider / model。

    let outcome = await ConversationSummarizer().summarize(conversationID: id, chatService: chatService)

    #expect(outcome.usedFallback == true)
    #expect(outcome.summary.contains("do the thing"))
    #expect(chatService.ephemeralCallCount == 0)
}

@MainActor
@Test func summarizeFallsBackWhenModelThrows() async {
    let id = UUID()
    let chatService = MockChatService()
    chatService.messagesByID[id] = [
        LumiChatMessage(conversationID: id, role: .user, content: "task one"),
        LumiChatMessage(conversationID: id, role: .assistant, content: "did part"),
    ]
    chatService.providerIDs[id] = "openai"
    chatService.modelNames[id] = "gpt-4o"
    struct Boom: Error {}
    chatService.ephemeralError = Boom()

    let outcome = await ConversationSummarizer().summarize(conversationID: id, chatService: chatService)

    #expect(outcome.usedFallback == true)
    // 回退摘要含最近 user 消息与最后 assistant 消息。
    #expect(outcome.summary.contains("task one"))
    #expect(outcome.summary.contains("did part"))
}

@MainActor
@Test func summarizeFallsBackWhenModelReturnsEmpty() async {
    let id = UUID()
    let chatService = MockChatService()
    chatService.messagesByID[id] = [
        LumiChatMessage(conversationID: id, role: .user, content: "ask"),
    ]
    chatService.providerIDs[id] = "openai"
    chatService.modelNames[id] = "gpt-4o"
    chatService.ephemeralResponse = LumiChatMessage(
        conversationID: id,
        role: .assistant,
        content: "   \n  "
    )

    let outcome = await ConversationSummarizer().summarize(conversationID: id, chatService: chatService)

    #expect(outcome.usedFallback == true)
    #expect(outcome.summary.contains("ask"))
}

@MainActor
@Test func summarizeIgnoresToolAndStatusMessages() async {
    let id = UUID()
    let chatService = MockChatService()
    chatService.messagesByID[id] = [
        LumiChatMessage(conversationID: id, role: .user, content: "real ask"),
        LumiChatMessage(conversationID: id, role: .tool, content: "tool output"),
        LumiChatMessage(conversationID: id, role: .status, content: "thinking..."),
        LumiChatMessage(conversationID: id, role: .assistant, content: ""),
    ]
    chatService.providerIDs[id] = "openai"
    chatService.modelNames[id] = "gpt-4o"

    _ = await ConversationSummarizer().summarize(conversationID: id, chatService: chatService)

    // 只有那条 user 消息会进入摘要请求的历史文本。
    let history = chatService.lastEphemeralMessages?.last?.content ?? ""
    #expect(history.contains("real ask"))
    #expect(!history.contains("tool output"))
    #expect(!history.contains("thinking..."))
}

// MARK: - MockChatService

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

    // 测试桩状态
    var messagesByID: [UUID: [LumiChatMessage]] = [:]
    var providerIDs: [UUID: String] = [:]
    var modelNames: [UUID: String] = [:]
    var ephemeralResponse: LumiChatMessage?
    var ephemeralError: (any Error)?
    private(set) var ephemeralCallCount = 0
    private(set) var lastEphemeralMessages: [LumiChatMessage]?
    private(set) var createdConversations: [(title: String?, projectPath: String?, language: LumiConversationLanguage?)] = []
    private(set) var enqueuedTexts: [(text: String, conversationID: UUID?)] = []

    func isSending(for conversationID: UUID?) -> Bool { false }

    func createConversation(title: String?) -> UUID {
        createConversation(title: title, projectPath: nil, language: nil)
    }

    func createConversation(title: String?, projectPath: String?, language: LumiConversationLanguage?) -> UUID {
        createdConversations.append((title: title, projectPath: projectPath, language: language))
        let new = UUID()
        selectedConversationID = new
        return new
    }

    func selectConversation(id: UUID) {}
    func deleteConversation(id: UUID) {}
    func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool { false }
    func setConversationProjectPath(_ projectPath: String?, for conversationID: UUID) -> Bool { false }
    func selectProvider(id: String, model: String?) {}
    func selectProvider(id: String, model: String?, for conversationID: UUID?) {}
    func providerID(for conversationID: UUID?) -> String? {
        conversationID.flatMap { providerIDs[$0] }
    }
    func provider(forID id: String) -> (any LumiLLMProvider)? { nil }
    func modelName(for conversationID: UUID?) -> String? {
        conversationID.flatMap { modelNames[$0] }
    }
    func setRoutingMode(_ mode: LumiModelRoutingMode) {}
    func language(for conversationID: UUID?) -> LumiConversationLanguage { .english }
    func setLanguage(_ language: LumiConversationLanguage, for conversationID: UUID?) {}
    func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel { .autonomous }
    func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?) {}
    func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity { .standard }
    func setVerbosity(_ verbosity: LumiResponseVerbosity, for conversationID: UUID?) {}
    func registerToolService(_ toolService: (any LumiToolServicing)?) {}
    func renderer(for message: LumiChatMessage) -> LumiMessageRendererItem? { nil }
    func messages(for conversationID: UUID) -> [LumiChatMessage] {
        messagesByID[conversationID] ?? []
    }
    func displayMessages(for conversationID: UUID) -> [LumiChatMessage] { messages(for: conversationID) }
    func transientStatusMessage(for conversationID: UUID) -> LumiChatMessage? { nil }
    func visibleMessages(for conversationID: UUID, limit: Int, beforeMessageID: UUID?) -> [LumiChatMessage] { [] }
    func hasEarlierMessages(for conversationID: UUID, beforeMessageID: UUID?) -> Bool { false }
    func enqueueText(_ text: String, in conversationID: UUID?) {
        enqueuedTexts.append((text: text, conversationID: conversationID))
    }
    func enqueueText(_ text: String, imageAttachments: [LumiImageAttachment], in conversationID: UUID?) {}
    func continueTurn(in conversationID: UUID) {}
    func cancelSending(for conversationID: UUID?) {}
    func approvePendingTool() {}
    func rejectPendingTool() {}
    func removePendingMessage(id: UUID) {}
    func deleteMessage(id: UUID, in conversationID: UUID) {}
    func resendMessage(id: UUID, in conversationID: UUID) async {}
    func send(_ text: String, in conversationID: UUID?) async {}
    func generateEphemeralCompletion(
        messages: [LumiChatMessage],
        model: String,
        conversationID: UUID
    ) async throws -> LumiChatMessage {
        ephemeralCallCount += 1
        lastEphemeralMessages = messages
        if let ephemeralError { throw ephemeralError }
        return ephemeralResponse ?? LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: ""
        )
    }
    func conversationContextUsage(for conversationID: UUID) -> LumiConversationContextUsage {
        .init(currentTokens: 0, limit: 0)
    }
}
