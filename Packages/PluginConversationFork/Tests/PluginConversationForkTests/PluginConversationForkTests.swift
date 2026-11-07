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

    @Test("renderHistory 渲染 user/assistant/tool 前缀")
    func renderHistory() {
        let id = UUID()
        let history = [
            Message(conversationID: id, role: .user, content: "hi"),
            Message(conversationID: id, role: .assistant, content: "hello"),
            Message(conversationID: id, role: .tool, content: "42", toolCallID: "call-1"),
        ]
        let rendered = ConversationSummarizer.renderHistory(history)
        #expect(rendered.contains("User: hi"))
        #expect(rendered.contains("Assistant: hello"))
        #expect(rendered.contains("Tool: 42"))
    }

    @Test("filteredMessages 保留工具调用与配对的工具结果")
    func filteredMessagesKeepsToolCallsAndResults() {
        let id = UUID()
        let call = MessageToolCall(
            id: "call-1",
            name: "run_command",
            arguments: #"{"command":"cat answer.txt"}"#
        )
        let history = [
            Message(conversationID: id, role: .user, content: "读取答案"),
            Message(conversationID: id, role: .assistant, content: "Done.", toolCalls: [call]),
            Message(conversationID: id, role: .tool, content: "42", toolCallID: "call-1"),
        ]

        let result = ConversationSummarizer.filteredMessages(history)

        #expect(result.count == 3)
        #expect(result[1].content.contains("[Tool call: run_command]"))
        #expect(result[1].content.contains("cat answer.txt"))
        #expect(result[2].content.contains("[Tool result for run_command]"))
        #expect(result[2].content.contains("42"))
    }

    @Test("正文为空的工具调用消息仍参与摘要")
    func filteredMessagesKeepsToolCallOnlyAssistant() {
        let id = UUID()
        let call = MessageToolCall(id: "call-1", name: "search_code", arguments: #"{"query":"foo"}"#)
        let result = ConversationSummarizer.filteredMessages([
            Message(conversationID: id, role: .assistant, content: "", toolCalls: [call]),
        ])

        #expect(result.count == 1)
        #expect(result[0].content.contains("[Tool call: search_code]"))
    }

    @Test("工具结果超长时按上限截断")
    func filteredMessagesTruncatesLongToolResult() {
        let id = UUID()
        let long = String(repeating: "y", count: ConversationSummarizer.maxToolResultChars + 100)
        let result = ConversationSummarizer.filteredMessages([
            Message(conversationID: id, role: .tool, content: long, toolCallID: "call-1"),
        ])

        #expect(result.count == 1)
        #expect(result[0].content.contains("[Tool result]"))
        #expect(result[0].content.hasSuffix("…[truncated]"))
        #expect(result[0].content.count <= ConversationSummarizer.maxToolResultChars
            + "[Tool result]\n\n".count + "…[truncated]".count)
    }

    @Test("回退摘要包含工具动作与结果")
    func summarizerFallbackIncludesToolActivity() async {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let llmProvider = DefaultLLMProviderManagerProviding()
        let id = UUID()
        let call = MessageToolCall(id: "call-1", name: "run_command", arguments: #"{"command":"cat answer.txt"}"#)
        messages.insertMessage(Message(conversationID: id, role: .user, content: "读取答案"), to: id)
        messages.insertMessage(
            Message(conversationID: id, role: .assistant, content: "Done.", toolCalls: [call]),
            to: id
        )
        messages.insertMessage(
            Message(conversationID: id, role: .tool, content: "42", toolCallID: "call-1"),
            to: id
        )

        let summarizer = ConversationSummarizer(
            conversations: conversations,
            messages: messages,
            llmProvider: llmProvider
        )
        let outcome = await summarizer.summarize(conversationID: id)

        #expect(outcome.usedFallback)
        #expect(outcome.summary.contains("run_command"))
        #expect(outcome.summary.contains("42"))
    }

    @Test("filteredMessages 丢弃 system 与空白消息")
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

    @Test("filteredMessages 保留仅带附件的消息，且不注入 base64")
    func filteredMessagesKeepsAttachmentOnlyMessages() {
        let id = UUID()
        let base64 = Data("secret-bytes".utf8).base64EncodedString()
        let file = UserFileAttachment(
            fileName: "requirements.md",
            mimeType: "text/markdown",
            textContent: "必须支持导出"
        )
        let image = UserImageAttachment(
            mimeType: "image/png",
            base64Data: base64,
            fileName: "mock.png"
        )
        var metadata = UserAttachmentMetadata.encodeFileAttachments([file])
        metadata.merge(UserAttachmentMetadata.encodeImageAttachments([image])) { _, new in new }

        let result = ConversationSummarizer.filteredMessages([
            Message(conversationID: id, role: .user, content: "   ", metadata: metadata),
        ])

        #expect(result.count == 1)
        #expect(result[0].content.contains("requirements.md"))
        #expect(result[0].content.contains("必须支持导出"))
        #expect(result[0].content.contains("mock.png"))
        #expect(!result[0].content.contains(base64))
    }

    @Test("二进制附件以文件名与本地路径表示")
    func binaryAttachmentDescription() {
        let file = UserFileAttachment(
            fileName: "design.zip",
            mimeType: "application/zip",
            base64Data: Data("zip-bytes".utf8).base64EncodedString(),
            localPath: "/tmp/design.zip"
        )
        let text = ConversationSummarizer.summaryText(for: Message(
            conversationID: UUID(),
            role: .user,
            content: "",
            metadata: UserAttachmentMetadata.encodeFileAttachments([file])
        ))

        let rendered = text ?? ""
        #expect(rendered.contains("design.zip"))
        #expect(rendered.contains("/tmp/design.zip"))
    }
}

@Suite("ConversationForkCoordinator")
@MainActor
struct ConversationForkCoordinatorTests {
    /// 组装一套完整的分叉依赖（无 LLM 供应商 → 摘要走本地回退）。
    private func makeCoordinator(
        conversations: any ConversationManaging,
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

    @Test("纯附件对话在 preview 中仍有内容并可 fork")
    func attachmentOnlyConversationCanFork() async throws {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let id = try conversations.createConversation(title: nil, projectPath: nil, providerID: nil, modelName: nil)
        let file = UserFileAttachment(
            fileName: "requirements.md",
            mimeType: "text/markdown",
            textContent: "必须支持导出"
        )
        messages.insertMessage(
            Message(
                conversationID: id,
                role: .user,
                content: "",
                metadata: UserAttachmentMetadata.encodeFileAttachments([file])
            ),
            to: id
        )

        let coordinator = makeCoordinator(conversations: conversations, messages: messages)
        let preview = await coordinator.preview(for: id)
        #expect(preview.hasContent)
        #expect(preview.requestCount == 1)
        #expect(preview.displayTitle.contains("requirements.md"))

        let outcome = try await coordinator.fork(conversationID: id)
        #expect(outcome.summary.contains("requirements.md"))
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

    @Test("fork 继承源对话的自动化级别、推理强度与详细程度")
    func forkInheritsConversationPreferences() async throws {
        let conversations = DefaultConversationManager()
        // 全局 New Chat 默认值与源对话不同，分叉不应取这些值。
        conversations.setGlobalAutomationLevel(.build)
        conversations.setGlobalReasoningEffort(.low)
        conversations.setGlobalVerbosity(.standard)

        let messages = DefaultMessageManager()
        let sourceID = try conversations.createConversation(title: "Chat 对话", projectPath: nil, providerID: nil, modelName: nil)
        conversations.setAutomationLevel(.chat, for: sourceID)
        conversations.setReasoningEffort(.max, for: sourceID)
        conversations.setVerbosity(.detailed, for: sourceID)
        messages.insertMessage(Message(conversationID: sourceID, role: .user, content: "问题"), to: sourceID)
        messages.insertMessage(Message(conversationID: sourceID, role: .assistant, content: "回答"), to: sourceID)

        let outcome = try await makeCoordinator(conversations: conversations, messages: messages)
            .fork(conversationID: sourceID)

        let forked = try #require(conversations.conversations.first { $0.id == outcome.newConversationID })
        #expect(forked.automationLevel == .chat)
        #expect(forked.reasoningEffort == .max)
        #expect(forked.verbosity == .detailed)
    }

    @Test("源对话关闭推理时 fork 不继承全局推理强度")
    func forkKeepsReasoningDisabledWhenSourceDisablesIt() async throws {
        let conversations = DefaultConversationManager()
        conversations.setGlobalReasoningEffort(.low)

        let messages = DefaultMessageManager()
        let sourceID = try conversations.createConversation(title: "无推理对话", projectPath: nil, providerID: nil, modelName: nil)
        conversations.clearReasoningEffort(for: sourceID)
        messages.insertMessage(Message(conversationID: sourceID, role: .user, content: "问题"), to: sourceID)
        messages.insertMessage(Message(conversationID: sourceID, role: .assistant, content: "回答"), to: sourceID)

        let outcome = try await makeCoordinator(conversations: conversations, messages: messages)
            .fork(conversationID: sourceID)

        let forked = try #require(conversations.conversations.first { $0.id == outcome.newConversationID })
        #expect(forked.reasoningEffort == nil)
    }

    @Test("fork 继承源对话语言，不受摘要期间切换会话影响")
    func forkUsesSourceConversationLanguage() async throws {
        let conversations = DefaultConversationManager()
        let messages = DefaultMessageManager()
        let sourceID = try conversations.createConversation(title: "English", projectPath: nil, providerID: nil, modelName: nil)
        conversations.setLanguage(.english, for: sourceID)
        let otherID = try conversations.createConversation(title: "中文", projectPath: nil, providerID: nil, modelName: nil)
        conversations.setLanguage(.chinese, for: otherID)
        // 模拟摘要期间用户从源对话切到另一个中文对话。
        conversations.selectConversation(id: otherID)
        messages.insertMessage(Message(conversationID: sourceID, role: .user, content: "Question"), to: sourceID)
        messages.insertMessage(Message(conversationID: sourceID, role: .assistant, content: "Answer"), to: sourceID)

        let outcome = try await makeCoordinator(conversations: conversations, messages: messages)
            .fork(conversationID: sourceID)

        let forked = try #require(conversations.conversations.first { $0.id == outcome.newConversationID })
        #expect(forked.language == .english)
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

    // MARK: - 项目绑定

    @Test("无项目源对话 fork 后副本仍无项目")
    func forkOfUnboundConversationStaysUnbound() async throws {
        // 复现生产实现：当前项目存在时，旧接口把 `projectPath: nil`
        // 解释成「沿用当前项目」。修复前 fork 正是这样传的。
        let conversations = CurrentProjectFallbackConversations(
            currentProjectPath: "/tmp/current-project"
        )
        let messages = DefaultMessageManager()
        let sourceID = try conversations.createConversation(
            title: "无项目对话",
            binding: .none,
            providerID: nil,
            modelName: nil
        )
        messages.insertMessage(Message(conversationID: sourceID, role: .user, content: "问题"), to: sourceID)
        messages.insertMessage(Message(conversationID: sourceID, role: .assistant, content: "回答"), to: sourceID)

        let outcome = try await makeCoordinator(conversations: conversations, messages: messages)
            .fork(conversationID: sourceID)

        let forked = try #require(conversations.conversations.first { $0.id == outcome.newConversationID })
        #expect(forked.projectPath == nil)
        #expect(forked.projectPath != "")
    }

    @Test("有项目源对话 fork 后沿用同一项目，不受当前项目影响")
    func forkOfBoundConversationKeepsItsProject() async throws {
        let conversations = CurrentProjectFallbackConversations(
            currentProjectPath: "/tmp/current-project"
        )
        let messages = DefaultMessageManager()
        let sourceID = try conversations.createConversation(
            title: "有项目对话",
            binding: .project("/tmp/source-project"),
            providerID: nil,
            modelName: nil
        )
        messages.insertMessage(Message(conversationID: sourceID, role: .user, content: "问题"), to: sourceID)
        messages.insertMessage(Message(conversationID: sourceID, role: .assistant, content: "回答"), to: sourceID)

        let outcome = try await makeCoordinator(conversations: conversations, messages: messages)
            .fork(conversationID: sourceID)

        let forked = try #require(conversations.conversations.first { $0.id == outcome.newConversationID })
        #expect(forked.projectPath == "/tmp/source-project")
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

// MARK: - 当前项目回退替身

/// 模拟生产 `ConversationManager` 的项目解析：旧接口收到 `projectPath: nil`
/// 时回退到当前项目；`ProjectBinding` 版本则尊重 `.none`。
///
/// 其余能力全部委托给 `DefaultConversationManager`，只替换「项目从哪来」
/// 这一层，以便在 fork 包内复现 #625。
@MainActor
private final class CurrentProjectFallbackConversations: ConversationManaging {
    private let base = DefaultConversationManager()
    private let currentProjectPath: String?

    init(currentProjectPath: String?) {
        self.currentProjectPath = currentProjectPath
    }

    var conversations: [ConversationSummary] { base.conversations }
    var selectedConversationID: UUID? { base.selectedConversationID }
    var currentTitle: String { base.currentTitle }
    var dataDirectory: URL { base.dataDirectory }

    func createConversation(
        title: String?,
        projectPath: String?,
        providerID: String?,
        modelName: String?
    ) throws -> UUID {
        try base.createConversation(
            title: title,
            projectPath: projectPath ?? currentProjectPath,
            providerID: providerID,
            modelName: modelName
        )
    }

    func createConversation(
        title: String?,
        projectPath: String?,
        providerID: String?,
        modelName: String?,
        parentConversationID: UUID?
    ) throws -> UUID {
        try base.createConversation(
            title: title,
            projectPath: projectPath ?? currentProjectPath,
            providerID: providerID,
            modelName: modelName,
            parentConversationID: parentConversationID
        )
    }

    func createConversation(
        title: String?,
        binding: ProjectBinding,
        providerID: String?,
        modelName: String?
    ) throws -> UUID {
        try base.createConversation(
            title: title,
            projectPath: binding.resolvedProjectPath(inheriting: currentProjectPath),
            providerID: providerID,
            modelName: modelName
        )
    }

    func createConversation(
        title: String?,
        binding: ProjectBinding,
        providerID: String?,
        modelName: String?,
        parentConversationID: UUID?
    ) throws -> UUID {
        try base.createConversation(
            title: title,
            projectPath: binding.resolvedProjectPath(inheriting: currentProjectPath),
            providerID: providerID,
            modelName: modelName,
            parentConversationID: parentConversationID
        )
    }

    func selectConversation(id: UUID) { base.selectConversation(id: id) }
    func deselectConversation() { base.deselectConversation() }
    func deleteConversation(id: UUID) { base.deleteConversation(id: id) }
    func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool {
        base.updateConversationTitle(title, for: conversationID)
    }
    func markConversationActive(id: UUID, messageDate: Date) {
        base.markConversationActive(id: id, messageDate: messageDate)
    }
    func isSending(for conversationID: UUID?) -> Bool { base.isSending(for: conversationID) }
    func providerID(for conversationID: UUID?) -> String? { base.providerID(for: conversationID) }
    func modelName(for conversationID: UUID?) -> String? { base.modelName(for: conversationID) }
    func selectProvider(id: String, model: String?, for conversationID: UUID?) {
        base.selectProvider(id: id, model: model, for: conversationID)
    }

    var globalVerbosity: ResponseVerbosity { base.globalVerbosity }
    func setGlobalVerbosity(_ verbosity: ResponseVerbosity) { base.setGlobalVerbosity(verbosity) }
    func setVerbosity(_ verbosity: ResponseVerbosity, for conversationID: UUID?) {
        base.setVerbosity(verbosity, for: conversationID)
    }
    func verbosity(for conversationID: UUID?) -> ResponseVerbosity { base.verbosity(for: conversationID) }

    var globalReasoningEffort: ReasoningEffort? { base.globalReasoningEffort }
    func setGlobalReasoningEffort(_ reasoningEffort: ReasoningEffort?) {
        base.setGlobalReasoningEffort(reasoningEffort)
    }
    func reasoningEffort(for conversationID: UUID?) -> ReasoningEffort {
        base.reasoningEffort(for: conversationID)
    }
    func reasoningEffortOptional(for conversationID: UUID?) -> ReasoningEffort? {
        base.reasoningEffortOptional(for: conversationID)
    }
    func setReasoningEffort(_ reasoningEffort: ReasoningEffort, for conversationID: UUID?) {
        base.setReasoningEffort(reasoningEffort, for: conversationID)
    }
    func clearReasoningEffort(for conversationID: UUID?) {
        base.clearReasoningEffort(for: conversationID)
    }

    var globalAutomationLevel: AutomationLevel { base.globalAutomationLevel }
    func setGlobalAutomationLevel(_ automationLevel: AutomationLevel) {
        base.setGlobalAutomationLevel(automationLevel)
    }
    func automationLevel(for conversationID: UUID?) -> AutomationLevel {
        base.automationLevel(for: conversationID)
    }
    func setAutomationLevel(_ automationLevel: AutomationLevel, for conversationID: UUID?) {
        base.setAutomationLevel(automationLevel, for: conversationID)
    }

    var globalLanguage: ConversationLanguage { base.globalLanguage }
    func setGlobalLanguage(_ language: ConversationLanguage) { base.setGlobalLanguage(language) }
    func language(for conversationID: UUID?) -> ConversationLanguage { base.language(for: conversationID) }
    func setLanguage(_ language: ConversationLanguage, for conversationID: UUID?) {
        base.setLanguage(language, for: conversationID)
    }

    func addSelectedConversationObserver(
        _ callback: @escaping (UUID?) -> Void
    ) -> any SelectedConversationObserverHandle {
        base.addSelectedConversationObserver(callback)
    }

    func conversationIDs(projectPath: String, updatedSince: Date?) async -> [String] {
        base.conversations
            .filter { $0.projectPath == projectPath }
            .map { $0.id.uuidString }
    }
}
