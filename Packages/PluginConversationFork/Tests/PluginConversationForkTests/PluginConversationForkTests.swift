import Foundation
import Testing
import ProviderConversation
import ProviderMessage
import ProviderLLMManager
import KitLLM
import ProviderMessageSender
import ProviderLifecycleHooks
import ProviderAgentLoop

@testable import PluginConversationFork

@Suite("ConversationForkPlugin")
@MainActor
struct ConversationForkPluginTests {
    @Test("Summarizer 回退摘要：无历史时返回占位")
    func summarizerEmptyFallback() async {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let llmProvider = DefaultLLMProviderManagerProviding()
        let summarizer = ConversationSummarizer(
            conversations: conversations,
            messages: messages,
            llmProvider: llmProvider
        )
        let id = UUID()
        let outcome = await summarizer.summarize(conversationID: id)
        #expect(outcome.usedFallback)
        #expect(outcome.summary == "(No prior context captured.)")
    }

    @Test("Summarizer 回退摘要：有历史时拼装本地摘要")
    func summarizerFallbackWithHistory() async {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let llmProvider = DefaultLLMProviderManagerProviding()
        let id = UUID()
        messages.insertMessage(Message(conversationID: id, role: .user, content: "帮我写个排序"), to: id)
        messages.insertMessage(Message(conversationID: id, role: .assistant, content: "用快速排序"), to: id)

        let summarizer = ConversationSummarizer(
            conversations: conversations,
            messages: messages,
            llmProvider: llmProvider
        )
        let outcome = await summarizer.summarize(conversationID: id)
        #expect(outcome.usedFallback)
        #expect(outcome.summary.contains("帮我写个排序"))
        #expect(outcome.summary.contains("快速排序"))
    }

    @Test("renderHistory 渲染 user/assistant 前缀")
    func renderHistory() {
        let id = UUID()
        let history = [
            Message(conversationID: id, role: .user, content: "hi"),
            Message(conversationID: id, role: .assistant, content: "hello"),
        ]
        let rendered = ConversationSummarizer.renderHistory(history)
        #expect(rendered.contains("User: hi"))
        #expect(rendered.contains("Assistant: hello"))
    }

    @Test("filteredMessages 只保留 user/assistant 且非空消息")
    func filteredMessagesDropsIrrelevantRolesAndEmpty() {
        let id = UUID()
        let history = [
            Message(conversationID: id, role: .system, content: "system prompt"),
            Message(conversationID: id, role: .user, content: "   "),
            Message(conversationID: id, role: .user, content: "real question"),
            Message(conversationID: id, role: .assistant, content: "answer"),
        ]
        let result = ConversationSummarizer.filteredMessages(history)
        #expect(result.map(\.content) == ["real question", "answer"])
    }

    @Test("filteredMessages 仅保留最近 maxMessages 条")
    func filteredMessagesKeepsRecentOnly() {
        let id = UUID()
        var history: [Message] = []
        for i in 0..<(ConversationSummarizer.maxMessages + 5) {
            history.append(Message(conversationID: id, role: .user, content: "m\(i)"))
        }
        let result = ConversationSummarizer.filteredMessages(history)
        #expect(result.count == ConversationSummarizer.maxMessages)
        #expect(result.first?.content == "m5")
        #expect(result.last?.content == "m\(ConversationSummarizer.maxMessages + 4)")
    }

    @Test("filteredMessages 截断超长单条消息")
    func filteredMessagesTruncatesLongContent() {
        let id = UUID()
        let long = String(repeating: "x", count: ConversationSummarizer.maxCharsPerMessage + 100)
        let result = ConversationSummarizer.filteredMessages([
            Message(conversationID: id, role: .user, content: long),
        ])
        #expect(result.count == 1)
        #expect(result[0].content.hasSuffix("…[truncated]"))
        #expect(result[0].content.count == ConversationSummarizer.maxCharsPerMessage + "…[truncated]".count)
    }

    @Test("Fork 按钮通过 sender 发送摘要到新对话")
    func forkSendsSummary() async throws {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let loop = StubAgentLoop(messages: messages)
        let sender = DefaultMessageSender(
            conversations: conversations,
            messages: messages,
            agentLoop: loop
        )
        let id = try conversations.createConversation(title: nil, projectPath: nil, providerID: nil, modelName: nil)
        conversations.selectConversation(id: id)
        messages.insertMessage(Message(conversationID: id, role: .user, content: "第一条"), to: id)

        // 直接验证 sender 可在新对话发消息（ForkButton 的发送路径）。
        try await sender.sendMessage("摘要内容", conversationID: id)
        let newID = try #require(conversations.selectedConversationID)
        #expect(messages.messages(for: newID).contains { $0.content == "摘要内容" })
    }
}

@Suite("ConversationForkCoordinator")
@MainActor
struct ConversationForkCoordinatorTests {
    /// 组装一套完整的分叉依赖（无 LLM 供应商 → 摘要走本地回退）。
    private func makeCoordinator(
        conversations: DefaultConversationManager,
        messages: DefaultMessageManager
    ) -> ConversationForkCoordinator {
        let loop = StubAgentLoop(messages: messages)
        let sender = DefaultMessageSender(
            conversations: conversations,
            messages: messages,
            agentLoop: loop
        )
        let summarizer = ConversationSummarizer(
            conversations: conversations,
            messages: messages,
            llmProvider: DefaultLLMProviderManagerProviding()
        )
        return ConversationForkCoordinator(
            conversations: conversations,
            messages: messages,
            sender: sender,
            summarizer: summarizer
        )
    }

    @Test("preview 统计参与摘要的消息条数与提问轮数")
    func previewCountsMessagesAndRequests() async throws {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let id = try conversations.createConversation(title: "旧对话", projectPath: "/tmp/proj", providerID: "openai", modelName: "gpt-4")
        messages.insertMessage(Message(conversationID: id, role: .user, content: "第一条问题"), to: id)
        messages.insertMessage(Message(conversationID: id, role: .assistant, content: "回答"), to: id)
        messages.insertMessage(Message(conversationID: id, role: .user, content: "第二条问题"), to: id)
        // system 消息不参与摘要，不应计入条数。
        messages.insertMessage(Message(conversationID: id, role: .system, content: "系统提示"), to: id)

        let preview = await makeCoordinator(conversations: conversations, messages: messages)
            .preview(for: id)

        #expect(preview.hasContent)
        #expect(preview.messageCount == 3)
        #expect(preview.requestCount == 2)
        #expect(preview.title == "旧对话")
        #expect(preview.lastRequest == "第二条问题")
        #expect(preview.modelName == "gpt-4")
        #expect(preview.projectPath == "/tmp/proj")
    }

    @Test("preview 对空对话标记为无内容")
    func previewEmptyConversation() async throws {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let id = try conversations.createConversation(title: nil, projectPath: nil, providerID: nil, modelName: nil)

        let preview = await makeCoordinator(conversations: conversations, messages: messages)
            .preview(for: id)

        #expect(!preview.hasContent)
        #expect(preview.messageCount == 0)
        #expect(preview.requestCount == 0)
        #expect(preview.lastRequest == nil)
    }

    @Test("preview 以传入的源对话为准，不跟随当前选中对话")
    func previewTargetsGivenConversation() async throws {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let sourceID = try conversations.createConversation(title: "源对话", projectPath: nil, providerID: nil, modelName: nil)
        messages.insertMessage(Message(conversationID: sourceID, role: .user, content: "源问题"), to: sourceID)

        let otherID = try conversations.createConversation(title: "别的对话", projectPath: nil, providerID: nil, modelName: nil)
        messages.insertMessage(Message(conversationID: otherID, role: .user, content: "别的问题"), to: otherID)
        conversations.selectConversation(id: otherID)

        let preview = await makeCoordinator(conversations: conversations, messages: messages)
            .preview(for: sourceID)

        #expect(preview.title == "源对话")
        #expect(preview.lastRequest == "源问题")
    }

    @Test("fork 建新对话、注入摘要并透传标题/项目/模型")
    func forkCreatesConversationAndSendsSummary() async throws {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let sourceID = try conversations.createConversation(
            title: "旧对话",
            projectPath: "/tmp/proj",
            providerID: "openai",
            modelName: "gpt-4"
        )
        messages.insertMessage(Message(conversationID: sourceID, role: .user, content: "第一条问题"), to: sourceID)
        messages.insertMessage(Message(conversationID: sourceID, role: .assistant, content: "回答"), to: sourceID)

        let outcome = try await makeCoordinator(conversations: conversations, messages: messages)
            .fork(conversationID: sourceID)

        #expect(outcome.newConversationID != sourceID)
        #expect(conversations.selectedConversationID == outcome.newConversationID)
        // 摘要作为首条 user 消息写入新对话。
        #expect(messages.messages(for: outcome.newConversationID).contains { $0.content == outcome.summary })

        let forked = try #require(conversations.conversations.first { $0.id == outcome.newConversationID })
        #expect(forked.title == "旧对话")
        #expect(forked.projectPath == "/tmp/proj")
        #expect(forked.modelName == "gpt-4")
    }

    @Test("fork 以传入的源对话为准，不跟随当前选中对话")
    func forkTargetsGivenConversation() async throws {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let sourceID = try conversations.createConversation(title: "源对话", projectPath: nil, providerID: nil, modelName: nil)
        messages.insertMessage(Message(conversationID: sourceID, role: .user, content: "源问题"), to: sourceID)

        let otherID = try conversations.createConversation(title: "别的对话", projectPath: nil, providerID: nil, modelName: nil)
        messages.insertMessage(Message(conversationID: otherID, role: .user, content: "别的问题"), to: otherID)
        conversations.selectConversation(id: otherID)

        let outcome = try await makeCoordinator(conversations: conversations, messages: messages)
            .fork(conversationID: sourceID)

        #expect(outcome.summary.contains("源问题"))
        #expect(!outcome.summary.contains("别的问题"))
    }

    @Test("fork 对空对话抛出 emptyConversation，且不新建对话")
    func forkEmptyConversationThrows() async throws {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let id = try conversations.createConversation(title: nil, projectPath: nil, providerID: nil, modelName: nil)
        let before = conversations.conversations.count

        await #expect(throws: ConversationForkCoordinator.ForkError.emptyConversation) {
            try await makeCoordinator(conversations: conversations, messages: messages).fork(conversationID: id)
        }

        #expect(conversations.conversations.count == before)
    }

    @Test("displayTitle 回退到最后一条提问")
    func displayTitleFallsBackToLastRequest() {
        #expect(ConversationForkPreview(
            title: nil,
            messageCount: 1,
            requestCount: 1,
            lastRequest: "最后一条提问",
            modelName: nil,
            projectPath: nil
        ).displayTitle == "最后一条提问")

        #expect(ConversationForkPreview(
            title: "  ",
            messageCount: 1,
            requestCount: 1,
            lastRequest: "最后一条提问",
            modelName: nil,
            projectPath: nil
        ).displayTitle == "最后一条提问")

        #expect(ConversationForkPreview(
            title: "标题",
            messageCount: 1,
            requestCount: 1,
            lastRequest: "最后一条提问",
            modelName: nil,
            projectPath: nil
        ).displayTitle == "标题")
    }

    @Test("truncate 截断超长文本并补省略号")
    func truncateLongText() {
        #expect(ConversationForkCoordinator.truncate("短文本", limit: 10) == "短文本")
        #expect(ConversationForkCoordinator.truncate("  短文本  ", limit: 10) == "短文本")
        let truncated = ConversationForkCoordinator.truncate(String(repeating: "x", count: 50), limit: 10)
        #expect(truncated == String(repeating: "x", count: 10) + "…")
    }
}

/// 测试用 AgentLoop 桩：保留 responder 语义，落库 assistant 消息。
@MainActor
private final class StubAgentLoop: AgentLoopProviding {
    private let messages: any MessageManaging
    private var observers: [UUID: (AgentLoopEvent) -> Void] = [:]
    private var messageObserver: (any MessageInsertedObserverHandle)?

    init(messages: any MessageManaging) {
        self.messages = messages
        messageObserver = messages.addMessageInsertedObserver { [weak self] message, conversationID in
            guard message.role == .user else { return }
            Task { @MainActor in
                _ = try? await self?.runTurn(in: conversationID)
            }
        }
    }

    func addAgentLoopObserver(
        _ callback: @escaping (AgentLoopEvent) -> Void
    ) -> any AgentLoopObserverHandle {
        let id = UUID()
        observers[id] = callback
        return StubAgentLoopObserverHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome {
        let event = AgentLoopEvent.completed(conversationID: conversationID, turnID: UUID())
        for observer in observers.values {
            observer(event)
        }
        return .completed
    }

    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome {
        throw AgentLoopError.invalidResumeRequest
    }

    func cancelTurn(in conversationID: UUID) {}
    func state(for conversationID: UUID) -> AgentLoopState { .idle }
    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }
    func isRunning(for conversationID: UUID) -> Bool { false }
    func currentTurnID(for conversationID: UUID) -> UUID? { nil }
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}

}

@MainActor
private final class StubAgentLoopObserverHandle: AgentLoopObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: @escaping () -> Void) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}
