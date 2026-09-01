import Testing
import Foundation
import KitLLM
import KitAgentTool
@testable import PluginAgentLoop
import ProviderAgentLoop
import ProviderConversation
import ProviderLifecycleHooks
import ProviderMessage
import ProviderMessageStreaming
import ProviderLLMContext
import ProviderLLMManager
import ProviderToolManager

@MainActor
@Test func testPluginInitialization() async throws {
    let plugin = PluginAgentLoop()
    #expect(plugin.id == "com.coffic.lumi.plugin.agent-loop")
    #expect(plugin.order == 8)
}

@MainActor
@Test func testPluginMetadata() async throws {
    let plugin = PluginAgentLoop()
    let metadata = plugin.metadata
    #expect(metadata.name == "Plugin Agent Loop")
    #expect(metadata.category == .core)
}

@Test("willSendToLLM message restoration preserves assistant tool calls")
func testMessageFromLLMMessagePreservesToolCalls() {
    let conversationID = UUID()
    let message = LLMMessage(
        role: .assistant,
        content: "",
        toolCalls: [
            LLMToolCall(id: "tool-1", name: "run_command", arguments: "{\"command\":\"git status\"}")
        ],
        reasoningContent: "先检查状态"
    )

    let restored = messageFromLLMMessage(message, conversationID: conversationID)

    #expect(restored.conversationID == conversationID)
    #expect(restored.toolCalls == [
        MessageToolCall(id: "tool-1", name: "run_command", arguments: "{\"command\":\"git status\"}")
    ])
    #expect(restored.reasoningContent == "先检查状态")
}

@Test("可恢复的 LLM 工具协议错误会重试当前回合")
func testRetryableLLMFailureRetriesCurrentTurn() {
    let turnID = UUID()
    let started = TurnReducer.reduce(
        TurnRuntime(),
        event: .startTurn(turnID: turnID)
    )
    #expect(started.1 == nil)

    let firstRetry = TurnReducer.reduce(
        started.0,
        event: .llmRetryableFailure(reason: "incomplete tool call")
    )
    #expect(firstRetry.1 == nil)
    #expect(firstRetry.0.phase == .requestingLLM(turnID: turnID))
    #expect(firstRetry.0.llmRecoveryAttempts == 1)
    #expect(firstRetry.0.llmRecoveryHint != nil)

    let secondRetry = TurnReducer.reduce(
        firstRetry.0,
        event: .llmRetryableFailure(reason: "incomplete tool call")
    )
    #expect(secondRetry.1 == nil)
    #expect(secondRetry.0.llmRecoveryAttempts == 2)

    let exhausted = TurnReducer.reduce(
        secondRetry.0,
        event: .llmRetryableFailure(reason: "incomplete tool call")
    )
    #expect(exhausted.1 == .failed("incomplete tool call"))
    #expect(exhausted.0.phase == .failed(reason: "incomplete tool call"))
}

@Test("LLM 成功响应会清除工具协议恢复状态")
func testSuccessfulLLMResponseClearsRecoveryState() {
    let turnID = UUID()
    let started = TurnReducer.reduce(
        TurnRuntime(),
        event: .startTurn(turnID: turnID)
    )
    let retried = TurnReducer.reduce(
        started.0,
        event: .llmRetryableFailure(reason: "incomplete tool call")
    )

    let response = LLMResponse(content: "继续处理")
    let succeeded = TurnReducer.reduce(
        retried.0,
        event: .llmResponded(response: response, assistantMessageID: UUID())
    )
    #expect(succeeded.1 == .completed)
    #expect(succeeded.0.llmRecoveryAttempts == 0)
    #expect(succeeded.0.llmRecoveryHint == nil)
}

@Test("用户图片附件会转换为 LLM 图片")
func testMessageToLLMMessagePreservesUserImage() {
    let imageData = Data([0x89, 0x50, 0x4E, 0x47])
    let message = Message(
        conversationID: UUID(),
        role: .user,
        content: "这张图是什么",
        metadata: UserAttachmentMetadata.encodeImageAttachments([
            UserImageAttachment(
                mimeType: "image/png",
                base64Data: imageData.base64EncodedString(),
                fileName: "screen.png"
            )
        ])
    )

    let llmMessage = message.llmMessage

    #expect(llmMessage.images == [MessageImage(data: imageData, mimeType: "image/png")])
}

@Test("LLM 图片恢复为消息时会保留附件 metadata")
func testMessageFromLLMMessagePreservesUserImage() {
    let conversationID = UUID()
    let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0])
    let message = LLMMessage(
        role: .user,
        content: "请描述图片",
        images: [MessageImage(data: imageData, mimeType: "image/jpeg")]
    )

    let restored = messageFromLLMMessage(message, conversationID: conversationID)
    let attachments = UserAttachmentMetadata.decodeImageAttachments(from: restored.metadata)

    #expect(restored.conversationID == conversationID)
    #expect(attachments.count == 1)
    #expect(attachments[0].mimeType == "image/jpeg")
    #expect(Data(base64Encoded: attachments[0].base64Data) == imageData)
}

@MainActor
@Test("挂起 ask_user 时发送新消息会跳过挂起点并恢复原回合")
func testMessageObserverResumesSuspendedTurnWhenUserContinuesChatting() async throws {
    let messages = DefaultMessageManager()
    let loop = RecordingAgentLoop()
    let observer = MessageObserver(messages: messages, agentLoop: loop)
    defer { observer.cancel() }

    let conversationID = UUID()
    messages.insertMessage(
        Message(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            toolCalls: [
                MessageToolCall(
                    id: "ask-1",
                    name: "ask_user",
                    arguments: "{\"question\":\"继续吗?\",\"mode\":\"yes_no\"}",
                    result: MessageToolResult(
                        content: "{\"question\":\"继续吗?\"}",
                        awaitingUserResponse: true
                    )
                )
            ]
        ),
        to: conversationID
    )
    messages.insertMessage(
        Message(conversationID: conversationID, role: .user, content: "继续聊"),
        to: conversationID
    )

    // MessageObserver 通过 Task 异步消费消息插入事件。
    try await Task.sleep(nanoseconds: 50_000_000)

    #expect(loop.runTurnCallCount == 0)
    let request = try #require(loop.resumeRequests.first)
    #expect(request.suspensionID == "userInput:ask-1")
    #expect(request.answer.contains("without answering"))
}

@MainActor
@Test("挂起高风险工具审批时发送新消息不会绕过审批")
func testMessageObserverDoesNotSkipNonAskUserSuspension() async throws {
    let messages = DefaultMessageManager()
    let loop = RecordingAgentLoop(suspensionToolCallID: "approval-1")
    let observer = MessageObserver(messages: messages, agentLoop: loop)
    defer { observer.cancel() }

    let conversationID = UUID()
    messages.insertMessage(
        Message(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            toolCalls: [
                MessageToolCall(
                    id: "approval-1",
                    name: "run_command",
                    arguments: "{}",
                    result: MessageToolResult(
                        content: "需要批准",
                        awaitingUserResponse: true
                    )
                )
            ]
        ),
        to: conversationID
    )
    messages.insertMessage(
        Message(conversationID: conversationID, role: .user, content: "继续聊"),
        to: conversationID
    )

    try await Task.sleep(nanoseconds: 50_000_000)

    #expect(loop.runTurnCallCount == 0)
    #expect(loop.resumeRequests.isEmpty)
}

@MainActor
@Test("应用重启后授权完成事件会从历史 assistant 消息恢复 Loop")
func testHistoricalAuthorizedCompletionRehydratesLoop() {
    let messages = DefaultMessageManager()
    let conversationID = UUID()
    let turnID = UUID()
    let assistantMessageID = UUID()
    let toolCallID = "historical-call"
    messages.insertMessage(
        Message(
            id: assistantMessageID,
            conversationID: conversationID,
            role: .assistant,
            content: "",
            turnID: turnID,
            toolCalls: [
                MessageToolCall(
                    id: toolCallID,
                    name: "edit_file",
                    arguments: "{}",
                    authorizationState: ToolCallAuthorizationState.pendingAuthorization.rawValue
                ),
                MessageToolCall(
                    id: "remaining-call",
                    name: "read_file",
                    arguments: "{}"
                ),
            ]
        ),
        to: conversationID
    )

    let toolManager = DefaultToolManagerProviding()
    let loop = AgentLoopManager(
        messages: messages,
        llmManager: DefaultLLMManager(),
        toolManager: toolManager,
        streaming: DefaultMessageStreamingProviding(),
        conversations: DefaultConversationManager(),
        contextProvider: PassthroughLLMContextProvider(messages: messages)
    )

    loop.handleToolManagerEvent(.authorizedCompleted(
        conversationID: conversationID,
        turnID: nil,
        toolCall: KitAgentTool.ToolCall(
            id: toolCallID,
            name: "edit_file",
            arguments: "{}",
            authorizationState: .userApproved
        ),
        result: ToolCallResult(content: "edited")
    ))

    let assistant = messages.message(id: assistantMessageID, in: conversationID)
    let updatedToolCall = assistant?.toolCalls?.first(where: { $0.id == toolCallID })
    #expect(updatedToolCall?.result?.content == "edited")
    #expect(updatedToolCall?.authorizationState == ToolCallAuthorizationState.userApproved.rawValue)
    #expect(loop.currentTurnID(for: conversationID) == turnID)
}

@MainActor
@Test("正常挂起回合收到授权完成事件后会继续剩余工具")
func testAuthorizedCompletionResumesSuspendedLoop() {
    let messages = DefaultMessageManager()
    let conversationID = UUID()
    let turnID = UUID()
    let assistantMessageID = UUID()
    let toolCallID = "suspended-call"
    messages.insertMessage(
        Message(
            id: assistantMessageID,
            conversationID: conversationID,
            role: .assistant,
            content: "",
            turnID: turnID,
            toolCalls: [
                MessageToolCall(id: toolCallID, name: "edit_file", arguments: "{}"),
                MessageToolCall(id: "remaining-call", name: "read_file", arguments: "{}"),
            ]
        ),
        to: conversationID
    )

    let loop = AgentLoopManager(
        messages: messages,
        llmManager: DefaultLLMManager(),
        toolManager: DefaultToolManagerProviding(),
        streaming: DefaultMessageStreamingProviding(),
        conversations: DefaultConversationManager(),
        contextProvider: PassthroughLLMContextProvider(messages: messages)
    )
    loop.runtimes[conversationID] = TurnRuntime(
        phase: .awaitingUser(
            turnID: turnID,
            assistantMessageID: assistantMessageID,
            pendingToolCalls: [
                MessageToolCall(id: "remaining-call", name: "read_file", arguments: "{}"),
            ],
            suspension: AgentLoopSuspension(
                suspensionID: "userInput:\(toolCallID)",
                conversationID: conversationID,
                toolCallID: toolCallID,
                kind: "permission",
                payload: "需要批准"
            )
        )
    )

    loop.handleToolManagerEvent(.authorizedCompleted(
        conversationID: conversationID,
        turnID: turnID,
        toolCall: KitAgentTool.ToolCall(
            id: toolCallID,
            name: "edit_file",
            arguments: "{}",
            authorizationState: .userApproved
        ),
        result: ToolCallResult(content: "edited")
    ))

    let updatedToolCall = messages.message(id: assistantMessageID, in: conversationID)?
        .toolCalls?.first(where: { $0.id == toolCallID })
    #expect(updatedToolCall?.result?.content == "edited")
    #expect(loop.currentTurnID(for: conversationID) == turnID)
}

@MainActor
private final class RecordingAgentLoop: AgentLoopProviding {
    private let pendingSuspension: AgentLoopSuspension

    private(set) var runTurnCallCount = 0
    private(set) var resumeRequests: [AgentTurnResumeRequest] = []

    init(suspensionToolCallID: String = "ask-1") {
        pendingSuspension = AgentLoopSuspension(
            suspensionID: "userInput:\(suspensionToolCallID)",
            conversationID: UUID(),
            toolCallID: suspensionToolCallID,
            kind: "userInput",
            payload: "{\"question\":\"继续吗?\"}"
        )
    }

    func addAgentLoopObserver(
        _ callback: @escaping (AgentLoopEvent) -> Void
    ) -> any AgentLoopObserverHandle {
        NoopAgentLoopObserverHandle()
    }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome {
        runTurnCallCount += 1
        return .completed
    }

    func resumeTurn(
        in conversationID: UUID,
        request: AgentTurnResumeRequest
    ) async throws -> AgentLoopOutcome {
        resumeRequests.append(request)
        return .completed
    }

    func cancelTurn(in conversationID: UUID) {}

    func state(for conversationID: UUID) -> AgentLoopState { .suspended }

    func suspension(for conversationID: UUID) -> AgentLoopSuspension? {
        AgentLoopSuspension(
            suspensionID: pendingSuspension.suspensionID,
            conversationID: conversationID,
            toolCallID: pendingSuspension.toolCallID,
            kind: pendingSuspension.kind,
            payload: pendingSuspension.payload
        )
    }

    func isRunning(for conversationID: UUID) -> Bool { true }

    func currentTurnID(for conversationID: UUID) -> UUID? { nil }

    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}
}

@MainActor
private final class NoopAgentLoopObserverHandle: AgentLoopObserverHandle {
    func cancel() {}
}
