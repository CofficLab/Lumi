import Foundation
import KernelCore
import KitLLM
import ProviderAgentLoop
import ProviderConversation
import ProviderLifecycleHooks
import ProviderLLMContext
import ProviderLLMManager
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager
import Testing

@testable import PluginAgentLoop

// MARK: - Fixtures

/// 构造一个最小可用的 `AgentLoopManager`（不触碰网络与磁盘）。
@MainActor
private func makeManager(
    messages: any MessageManaging? = nil
) -> AgentLoopManager {
    let messageStore = messages ?? DefaultMessageManager()
    return AgentLoopManager(
        messages: messageStore,
        llmManager: DefaultLLMManager(),
        toolManager: DefaultToolManagerProviding(),
        streaming: DefaultMessageStreamingProviding(),
        conversations: DefaultConversationManager(),
        contextProvider: PassthroughLLMContextProvider(messages: messageStore)
    )
}

private func assistantMessage(
    conversationID: UUID,
    turnID: UUID?,
    toolCalls: [MessageToolCall]
) -> Message {
    Message(
        conversationID: conversationID,
        role: .assistant,
        content: "",
        turnID: turnID,
        toolCalls: toolCalls
    )
}

private func toolMessage(
    conversationID: UUID,
    turnID: UUID?,
    toolCallID: String
) -> Message {
    Message(
        conversationID: conversationID,
        role: .tool,
        content: "tool output",
        turnID: turnID,
        toolCallID: toolCallID
    )
}

/// 遵循 `LLMErrorRenderInfo` 的测试错误。
private struct RenderInfoError: LocalizedError, LLMErrorRenderInfo {
    let renderKind: String?
    let rawErrorDetail: String?

    var errorDescription: String? { "boom" }
}

// MARK: - Message helpers

@MainActor
@Suite("AgentLoop 消息辅助")
struct AgentLoopMessageHelperTests {

    @Test("insertToolResultMessage 写入 tool 消息并带上结果与调用 id")
    func insertsToolResultMessage() async throws {
        let messages = DefaultMessageManager()
        let manager = makeManager(messages: messages)
        let conversationID = UUID()
        let turnID = UUID()

        manager.insertToolResultMessage(
            .init(content: "42", duration: 0.25, isError: true),
            toolCallID: "call-1",
            conversationID: conversationID,
            turnID: turnID
        )

        let stored = await messages.messagesSnapshot(in: conversationID)
        #expect(stored.count == 1)
        let message = try #require(stored.first)
        #expect(message.role == .tool)
        #expect(message.content == "42")
        #expect(message.toolCallID == "call-1")
        #expect(message.isError)
        #expect(message.turnID == turnID)
    }

    @Test("appendError(content:) 写入 error 角色消息")
    func appendsPlainError() async throws {
        let messages = DefaultMessageManager()
        let manager = makeManager(messages: messages)
        let conversationID = UUID()
        let turnID = UUID()

        await manager.appendError(in: conversationID, content: "网络错误", turnID: turnID)

        let stored = await messages.messagesSnapshot(in: conversationID)
        let message = try #require(stored.first)
        #expect(message.role == .error)
        #expect(message.content == "网络错误")
        #expect(message.turnID == turnID)
    }

    @Test("appendError(error:) 透传渲染信息与思考内容")
    func appendsRenderedError() async throws {
        let messages = DefaultMessageManager()
        let manager = makeManager(messages: messages)
        let conversationID = UUID()

        await manager.appendError(
            in: conversationID,
            error: RenderInfoError(renderKind: "llm-provider-api-key-missing", rawErrorDetail: "detail text"),
            turnID: nil,
            reasoningContent: "thinking..."
        )

        let stored = await messages.messagesSnapshot(in: conversationID)
        let message = try #require(stored.first)
        #expect(message.role == .error)
        #expect(message.content == "boom")
        #expect(message.renderKind == "llm-provider-api-key-missing")
        #expect(message.rawErrorDetail == "detail text")
        #expect(message.reasoningContent == "thinking...")
    }

    @Test("未完成渲染信息的错误只写默认描述")
    func appendsErrorWithoutRenderInfo() async throws {
        let messages = DefaultMessageManager()
        let manager = makeManager(messages: messages)
        let conversationID = UUID()

        await manager.appendError(in: conversationID, error: RenderInfoError(renderKind: nil, rawErrorDetail: nil))

        let stored = await messages.messagesSnapshot(in: conversationID)
        let message = try #require(stored.first)
        #expect(message.role == .error)
        #expect(message.renderKind == nil)
        #expect(message.rawErrorDetail == nil)
    }

    @Test("incompleteToolCallMessage 找到仍缺少结果的工具调用")
    func findsIncompleteToolCall() throws {
        let manager = makeManager()
        let conversationID = UUID()
        let turnID = UUID()
        let pending = MessageToolCall(id: "call-1", name: "read", arguments: "{}")

        let message = assistantMessage(conversationID: conversationID, turnID: turnID, toolCalls: [pending])
        let found = manager.incompleteToolCallMessage(messages: [message])

        #expect(found?.id == message.id)
    }

    @Test("工具调用已有结果时不算未完成")
    func ignoresResolvedToolCall() {
        let manager = makeManager()
        let conversationID = UUID()
        let turnID = UUID()
        let resolved = MessageToolCall(
            id: "call-1",
            name: "read",
            arguments: "{}",
            result: .init(content: "done")
        )

        let message = assistantMessage(conversationID: conversationID, turnID: turnID, toolCalls: [resolved])
        #expect(manager.incompleteToolCallMessage(messages: [message]) == nil)
    }

    @Test("同一回合内已由 tool 消息回填的调用不算未完成")
    func ignoresToolFilledCall() {
        let manager = makeManager()
        let conversationID = UUID()
        let turnID = UUID()
        let pending = MessageToolCall(id: "call-1", name: "read", arguments: "{}")

        let assistant = assistantMessage(conversationID: conversationID, turnID: turnID, toolCalls: [pending])
        let tool = toolMessage(conversationID: conversationID, turnID: turnID, toolCallID: "call-1")

        #expect(manager.incompleteToolCallMessage(messages: [assistant, tool]) == nil)
    }

    @Test("tool 消息属于其他回合时不视为已回填")
    func treatsOtherTurnAsUnfilled() {
        let manager = makeManager()
        let conversationID = UUID()
        let turnID = UUID()
        let otherTurnID = UUID()
        let pending = MessageToolCall(id: "call-1", name: "read", arguments: "{}")

        let assistant = assistantMessage(conversationID: conversationID, turnID: turnID, toolCalls: [pending])
        let tool = toolMessage(conversationID: conversationID, turnID: otherTurnID, toolCallID: "call-1")

        #expect(manager.incompleteToolCallMessage(messages: [assistant, tool])?.id == assistant.id)
    }

    @Test("没有工具调用时返回 nil")
    func returnsNilWithoutToolCalls() {
        let manager = makeManager()
        let conversationID = UUID()
        let plain = Message(conversationID: conversationID, role: .user, content: "hi")
        #expect(manager.incompleteToolCallMessage(messages: [plain]) == nil)
    }

    @Test("latestAssistantToolCalls 取最近一条带工具调用的 assistant 消息")
    func latestAssistantToolCalls() {
        let manager = makeManager()
        let conversationID = UUID()
        let older = assistantMessage(
            conversationID: conversationID,
            turnID: nil,
            toolCalls: [MessageToolCall(id: "old", name: "a", arguments: "{}")]
        )
        let newer = assistantMessage(
            conversationID: conversationID,
            turnID: nil,
            toolCalls: [MessageToolCall(id: "new", name: "b", arguments: "{}")]
        )

        let calls = manager.latestAssistantToolCalls(messages: [older, newer])
        #expect(calls?.map(\.id) == ["new"])
    }

    @Test("latestAssistantToolCalls 在没有工具调用时返回 nil")
    func latestAssistantToolCallsWithoutAny() {
        let manager = makeManager()
        let conversationID = UUID()
        let plain = Message(conversationID: conversationID, role: .assistant, content: "text")
        #expect(manager.latestAssistantToolCalls(messages: [plain]) == nil)
    }

    @Test("notifyLLMResponse 发布 toolCallsReceived 事件")
    func notifiesToolCallsReceived() async throws {
        let manager = makeManager()
        let conversationID = UUID()
        let turnID = UUID()
        let assistantMessageID = UUID()
        let toolCalls = [MessageToolCall(id: "call-1", name: "read", arguments: "{}")]

        let box = EventBox()
        let handle = manager.addAgentLoopObserver { event in
            if case let .toolCallsReceived(conversation, turn, assistant, calls) = event {
                box.conversationID = conversation
                box.turnID = turn
                box.assistantMessageID = assistant
                box.toolCalls = calls
            }
        }
        defer { handle.cancel() }

        manager.notifyLLMResponse(
            conversationID: conversationID,
            turnID: turnID,
            assistantMessageID: assistantMessageID,
            toolCalls: toolCalls
        )

        #expect(box.conversationID == conversationID)
        #expect(box.turnID == turnID)
        #expect(box.assistantMessageID == assistantMessageID)
        #expect(box.toolCalls?.map(\.id) == ["call-1"])
    }
}

/// 记录观察到的 AgentLoop / 工具事件。
@MainActor
private final class EventBox {
    var conversationID: UUID?
    var turnID: UUID?
    var assistantMessageID: UUID?
    var toolCalls: [MessageToolCall]?
    var jobEventCount = 0
}

// MARK: - Plugin lifecycle

@MainActor
@Suite("PluginAgentLoop 生命周期")
struct PluginAgentLoopLifecycleTests {

    @Test("插件元数据稳定")
    func pluginMetadata() {
        let plugin = PluginAgentLoop()
        #expect(plugin.id == "com.coffic.lumi.plugin.agent-loop")
        #expect(plugin.order == 8)
        #expect(plugin.metadata.category == .core)
        #expect(plugin.metadata.stage == .stable)
        #expect(plugin.metadata.policy == .alwaysOn)
    }

    @Test("缺少必需 Provider 时 onBoot 直接返回且不注册 AgentLoopProviding")
    func onBootWithoutProvidersDoesNothing() throws {
        let kernel = KernelCoreContainer()
        let plugin = PluginAgentLoop()

        try plugin.onBoot(kernel: kernel)

        #expect(kernel.resolveProvider((any AgentLoopProviding).self) == nil)
    }

    @Test("依赖齐备时 onBoot 注册自定义 AgentLoopProviding")
    func onBootRegistersAgentLoopProvider() throws {
        let kernel = KernelCoreContainer()
        let messages = DefaultMessageManager()
        try kernel.registerProvider((any MessageManaging).self, messages)
        try kernel.registerProvider((any LLMManaging).self, DefaultLLMManager())
        try kernel.registerProvider((any ToolManagerProviding).self, DefaultToolManagerProviding())
        try kernel.registerProvider((any MessageStreamingProviding).self, DefaultMessageStreamingProviding())
        try kernel.registerProvider((any ConversationManaging).self, DefaultConversationManager())
        try kernel.registerProvider(
            (any LLMContextProviding).self,
            PassthroughLLMContextProvider(messages: messages)
        )

        let plugin = PluginAgentLoop()
        try plugin.onBoot(kernel: kernel)

        let resolved = kernel.resolveProvider((any AgentLoopProviding).self)
        #expect(resolved is AgentLoopManager)
    }

    @Test("onBoot 会替换内核中已有的默认 AgentLoopProviding")
    func onBootReplacesExistingProvider() throws {
        let kernel = KernelCoreContainer()
        let messages = DefaultMessageManager()
        try kernel.registerProvider((any MessageManaging).self, messages)
        try kernel.registerProvider((any LLMManaging).self, DefaultLLMManager())
        try kernel.registerProvider((any ToolManagerProviding).self, DefaultToolManagerProviding())
        try kernel.registerProvider((any MessageStreamingProviding).self, DefaultMessageStreamingProviding())
        try kernel.registerProvider((any ConversationManaging).self, DefaultConversationManager())
        try kernel.registerProvider(
            (any LLMContextProviding).self,
            PassthroughLLMContextProvider(messages: messages)
        )
        let previous = DefaultAgentLoopProvider(
            messages: messages,
            llmManager: DefaultLLMManager(),
            toolManager: DefaultToolManagerProviding(),
            streaming: DefaultMessageStreamingProviding(),
            conversations: DefaultConversationManager()
        )
        try kernel.registerProvider((any AgentLoopProviding).self, previous)

        let plugin = PluginAgentLoop()
        try plugin.onBoot(kernel: kernel)

        let resolved = kernel.resolveProvider((any AgentLoopProviding).self)
        #expect(resolved is AgentLoopManager)
        #expect(!(resolved === previous))
    }

    @Test("onReady 缺少 Provider 时不抛错")
    func onReadyWithoutProvidersDoesNothing() throws {
        let kernel = KernelCoreContainer()
        let plugin = PluginAgentLoop()
        try plugin.onReady(kernel: kernel)
    }

    @Test("onShutdown 释放观察者且不抛错")
    func onShutdownIsSafe() throws {
        let kernel = KernelCoreContainer()
        let plugin = PluginAgentLoop()
        try plugin.onShutdown(kernel: kernel)
    }
}

// MARK: - Observers

@MainActor
@Suite("AgentLoop 工具观察者")
struct AgentLoopToolObserverTests {

    @Test("ToolJobObserver 订阅后可安全取消，重复取消为空操作")
    func toolJobObserverCancels() {
        let toolManager = DefaultToolManagerProviding()
        let observer = ToolJobObserver(toolManager: toolManager) { _ in }

        observer.cancel()
        observer.cancel()
    }

    @Test("ToolManagerObserver 在 AgentLoop 不是 AgentLoopManager 时不崩溃")
    func toolManagerObserverHandlesForeignAgentLoop() {
        let toolManager = DefaultToolManagerProviding()
        let observer = ToolManagerObserver(toolManager: toolManager, agentLoop: StubAgentLoopProvider())
        observer.cancel()
    }

    @Test("ToolManagerObserver 订阅真实 ToolManager 后可取消")
    func toolManagerObserverSubscribesAndCancels() {
        let toolManager = DefaultToolManagerProviding()
        let observer = ToolManagerObserver(toolManager: toolManager, agentLoop: StubAgentLoopProvider())
        observer.cancel()
        observer.cancel()
    }
}

/// 仅用于满足 `AgentLoopProviding` 的最小桩。
@MainActor
private final class StubAgentLoopProvider: AgentLoopProviding {
    func addAgentLoopObserver(
        _ callback: @escaping (AgentLoopEvent) -> Void
    ) -> any AgentLoopObserverHandle {
        StubAgentLoopObserverHandle()
    }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome {
        throw StubError.unsupported
    }

    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome {
        throw StubError.unsupported
    }

    func cancelTurn(in conversationID: UUID) {}

    func retryTurn(in conversationID: UUID, after failedTurnID: UUID) async throws -> AgentLoopOutcome {
        throw StubError.unsupported
    }

    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}

    func state(for conversationID: UUID) -> AgentLoopState { .idle }

    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }

    func isRunning(for conversationID: UUID) -> Bool { false }

    func currentTurnID(for conversationID: UUID) -> UUID? { nil }

    func setAutoReplySuppressed(_ suppressed: Bool, for conversationID: UUID) {}
}

@MainActor
private final class StubAgentLoopObserverHandle: AgentLoopObserverHandle {
    func cancel() {}
}

private enum StubError: Error { case unsupported }
