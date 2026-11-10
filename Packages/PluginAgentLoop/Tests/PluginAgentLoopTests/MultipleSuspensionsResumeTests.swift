import Foundation
import KitAgentTool
import KitLLM
import ProviderAgentLoop
import ProviderConversation
import ProviderLLMContext
import ProviderLLMManager
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager
import Testing
@testable import PluginAgentLoop

/// 同一 assistant 批次里多个交互工具先后挂起时的恢复语义。
///
/// ## 背景
///
/// 状态机只把最近一次挂起放进 `phase` 作为 active suspension，其余保存在
/// `pendingSuspensions`。交互 Job 完成后执行位会被释放，因此 B 可以在 A
/// 仍挂起时开始执行并挂起——此时 pending 集合为空，A 只剩在字典里。
///
/// 旧实现恢复 B 后直接进入下一次 LLM 请求：A 既不在 pending 集合、也没有
/// active suspension，永远拿不到 `role=tool` 结果，下一轮请求就会缺少必需
/// 的工具结果。
///
/// 本套件锁定修复后的顺序：先把剩余挂起点停成新的 active suspension，
/// 全部回答完才允许发起下一次 LLM 请求。
@MainActor
@Suite("同一批次多个挂起点的恢复")
struct MultipleSuspensionsResumeTests {

    @Test("恢复一个挂起后停在剩余挂起点，不发起 LLM 请求")
    func resumingOneSuspensionKeepsRemainingActive() async throws {
        let fixture = Fixture()

        let outcome = try await fixture.loop.resumeTurn(
            in: fixture.conversationID,
            request: AgentTurnResumeRequest(
                suspensionID: "userInput:call_b",
                answer: "answer b"
            )
        )

        #expect(outcome == .suspended("userInput:call_a"))
        #expect(fixture.loop.state(for: fixture.conversationID) == .suspended)
        #expect(fixture.loop.suspension(for: fixture.conversationID)?.toolCallID == "call_a")
        #expect(
            fixture.llm.requestCount == 0,
            "还有未回答的挂起点时不得发起下一次 LLM 请求"
        )

        let calls = fixture.assistantToolCalls()
        let callA = calls.first { $0.id == "call_a" }
        let callB = calls.first { $0.id == "call_b" }
        #expect(callB?.result?.awaitingUserResponse == false, "已回答的 B 应拿到真实结果")
        #expect(callA?.result?.awaitingUserResponse == true, "A 仍在等待用户回答")
        #expect(fixture.toolMessages(for: "call_a").isEmpty, "A 尚无角色为 tool 的结果消息")

        // 挂起事件由 finishTurn 异步投递，等观察者收到。
        await waitUntil { !fixture.observedSuspensionIDs.isEmpty }

        // 观察者必须收到「停在 A」的挂起事件，否则输入区不知道还要继续提问。
        #expect(fixture.observedSuspensionIDs == ["userInput:call_a"])
    }

    @Test("依次回答全部挂起后才发起下一次 LLM 请求")
    func allSuspensionsMustBeAnsweredBeforeNextLLMRequest() async throws {
        let fixture = Fixture()

        _ = try await fixture.loop.resumeTurn(
            in: fixture.conversationID,
            request: AgentTurnResumeRequest(
                suspensionID: "userInput:call_b",
                answer: "answer b"
            )
        )
        #expect(fixture.llm.requestCount == 0)

        let outcome = try await fixture.loop.resumeTurn(
            in: fixture.conversationID,
            request: AgentTurnResumeRequest(
                suspensionID: "userInput:call_a",
                answer: "answer a"
            )
        )

        #expect(outcome == .completed)
        #expect(fixture.llm.requestCount == 1, "两个挂起都回答完才允许请求 LLM")
        #expect(fixture.toolMessages(for: "call_a").count == 1)
        #expect(fixture.toolMessages(for: "call_b").count == 1)
        #expect(fixture.loop.state(for: fixture.conversationID) == .completed)
    }

    @Test("只有一个挂起时行为不变，直接继续回合")
    func singleSuspensionStillContinuesAfterResume() async throws {
        let fixture = Fixture(suspensions: ["call_a"])
        fixture.installSingleSuspension("call_a")

        let outcome = try await fixture.loop.resumeTurn(
            in: fixture.conversationID,
            request: AgentTurnResumeRequest(
                suspensionID: "userInput:call_a",
                answer: "answer a"
            )
        )

        #expect(outcome == .completed)
        #expect(fixture.llm.requestCount == 1)
        #expect(fixture.observedSuspensionIDs.isEmpty)
    }

    /// 回归 #944：恢复后没有剩余工具调用时，这条路径曾经不发布任何运行
    /// 事件。会话状态由 AgentLoop 事件驱动，订阅方因此一直停在
    /// `.suspended`，模型已经开始下一次请求而侧边栏仍显示暂停。
    @Test("恢复后必须重新声明运行中")
    func resumePublishesRunningEvent() async throws {
        let fixture = Fixture(suspensions: ["call_a"])
        fixture.installSingleSuspension("call_a")

        _ = try await fixture.loop.resumeTurn(
            in: fixture.conversationID,
            request: AgentTurnResumeRequest(
                suspensionID: "userInput:call_a",
                answer: "answer a"
            )
        )

        #expect(
            fixture.observedStartedTurnIDs == [fixture.turnID],
            "恢复路径必须发布可让会话状态回到 running 的回合事件"
        )
    }
}

// MARK: - Fixture

@MainActor
private func waitUntil(
    _ condition: () -> Bool
) async {
    for _ in 0..<200 {
        if condition() { return }
        try? await Task.sleep(nanoseconds: 2_000_000)
    }
}

@MainActor
private final class Fixture {
    let messages: DefaultMessageManager
    let conversationID = UUID()
    let turnID = UUID()
    let assistantMessageID = UUID()
    let llm = CountingLLMManager()
    let loop: AgentLoopManager
    private(set) var observedSuspensionIDs: [String] = []
    private(set) var observedStartedTurnIDs: [UUID] = []

    /// - Parameter suspensions: 预先挂起的工具调用 ID，按给定顺序挂起。
    init(suspensions: [String] = ["call_a", "call_b"]) {
        let messages = DefaultMessageManager()
        self.messages = messages
        self.loop = AgentLoopManager(
            messages: messages,
            llmManager: llm,
            toolManager: PassiveResolveToolManager(),
            streaming: DefaultMessageStreamingProviding(),
            conversations: DefaultConversationManager(),
            contextProvider: PassthroughLLMContextProvider(messages: messages)
        )

        let toolCalls = suspensions.map { toolCallID in
            MessageToolCall(
                id: toolCallID,
                name: "ask_user",
                arguments: #"{"question":"继续吗？"}"#,
                result: MessageToolResult(
                    content: #"{"toolCallId":"ask_user","question":"继续吗？"}"#,
                    awaitingUserResponse: true,
                    interactionState: .waiting
                )
            )
        }
        messages.insertMessage(
            Message(
                id: assistantMessageID,
                conversationID: conversationID,
                role: .assistant,
                content: "",
                turnID: turnID,
                toolCalls: toolCalls
            ),
            to: conversationID
        )

        var pendingSuspensions: [String: AgentLoopSuspension] = [:]
        for toolCallID in suspensions {
            pendingSuspensions[toolCallID] = suspension(toolCallID: toolCallID)
        }
        let activeToolCallID = suspensions.last ?? "call_a"
        loop.runtimes[conversationID] = TurnRuntime(
            phase: .awaitingUser(
                turnID: turnID,
                assistantMessageID: assistantMessageID,
                pendingToolCalls: [],
                suspension: suspension(toolCallID: activeToolCallID)
            ),
            lastTurnID: turnID,
            pendingSuspensions: pendingSuspensions,
            suspensionOrder: suspensions,
            suspensionAssistantMessageID: assistantMessageID
        )

        _ = loop.addAgentLoopObserver { [weak self] event in
            switch event {
            case .started(_, let startedTurnID):
                self?.observedStartedTurnIDs.append(startedTurnID)
            case .suspended(_, _, let suspension):
                self?.observedSuspensionIDs.append(suspension.suspensionID)
            default:
                break
            }
        }
    }

    /// 把运行时压成「只剩一个挂起调用」的状态，用于覆盖恢复后直接进入
    /// 下一次 LLM 请求的路径。
    func installSingleSuspension(_ toolCallID: String) {
        let suspension = suspension(toolCallID: toolCallID)
        loop.runtimes[conversationID] = TurnRuntime(
            phase: .awaitingUser(
                turnID: turnID,
                assistantMessageID: assistantMessageID,
                pendingToolCalls: [],
                suspension: suspension
            ),
            lastTurnID: turnID,
            pendingSuspensions: [toolCallID: suspension],
            suspensionOrder: [toolCallID],
            suspensionAssistantMessageID: assistantMessageID
        )
    }

    func suspension(toolCallID: String) -> AgentLoopSuspension {
        AgentLoopSuspension(
            suspensionID: "userInput:\(toolCallID)",
            conversationID: conversationID,
            toolCallID: toolCallID,
            kind: "userInput",
            payload: #"{"toolCallId":"ask_user","question":"继续吗？"}"#
        )
    }

    func assistantToolCalls() -> [MessageToolCall] {
        messages.message(id: assistantMessageID, in: conversationID)?.toolCalls ?? []
    }

    func toolMessages(for toolCallID: String) -> [Message] {
        messages.messages(for: conversationID).filter {
            $0.role == .tool && $0.toolCallID == toolCallID
        }
    }
}

// MARK: - Stubs

/// 立即把用户回答当作工具结果返回的 ToolManager。
@MainActor
private final class PassiveResolveToolManager: ToolManagerProviding {
    func resolveUserResponse(
        _ answer: String,
        for toolCall: KitAgentTool.ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult {
        ToolCallResult(content: answer)
    }

    @discardableResult
    func addToolManagerObserver(
        _ callback: @escaping (ToolManagerEvent) -> Void
    ) -> any ToolManagerObserverHandle {
        NoopToolManagerObserverHandle()
    }

    @discardableResult
    func addToolJobObserver(
        _ callback: @escaping (ToolJobEvent) -> Void
    ) -> any ToolJobObserverHandle {
        NoopToolJobObserverHandle()
    }

    func allTools() -> [any SuperAgentTool] { [] }
    func add(_ tool: any SuperAgentTool, pluginID: String) {}
    func remove(id: String) {}
    func toolsGroupedByPlugin() -> [(pluginID: String, tools: [any SuperAgentTool])] { [] }
    func tool(named name: String) -> (any SuperAgentTool)? { nil }
    func displayDescription(for toolCall: KitAgentTool.ToolCall) -> String? { nil }
    func riskLevel(for toolCall: KitAgentTool.ToolCall) -> CommandRiskLevel? { nil }
    func authorizationDecision(
        for toolCall: KitAgentTool.ToolCall,
        conversationID: UUID
    ) -> ToolAuthorizationDecision { .autoApproved }
    func execute(
        _ toolCall: KitAgentTool.ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult { ToolCallResult(content: "unused") }
    func toolCalls(for turnID: UUID) async -> [ToolCallRecord] { [] }
    func toolCallResult(for toolCallID: String) async -> ToolCallResult? { nil }
    func deleteToolCalls(for conversationID: UUID) async {}
    func cancelJobs(forTurnID turnID: UUID) {}

    @MainActor
    final class NoopToolManagerObserverHandle: ToolManagerObserverHandle {
        func cancel() {}
    }

    @MainActor
    final class NoopToolJobObserverHandle: ToolJobObserverHandle {
        func cancel() {}
    }
}

/// 记录请求次数并立即返回无工具调用的响应。
@MainActor
private final class CountingLLMManager: LLMManaging, LLMStreamingProviding, @unchecked Sendable {
    private(set) var requestCount = 0

    var providerID: String { "counting-test" }
    var providerInfo: LLMProviderInfo {
        LLMProviderInfo(
            id: providerID,
            displayName: "Counting Test",
            defaultModel: "test-model",
            models: [LLMModelInfo(id: "test-model")],
            isLocal: true
        )
    }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        try await streamComplete(request) { _ in }
    }

    func streamComplete(
        _ request: LLMRequest,
        onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
    ) async throws -> LLMResponse {
        requestCount += 1
        return LLMResponse(content: "done", model: request.model)
    }

    func allProviders() -> [any SuperLLMProvider] { [self] }
    func provider(id: String) -> (any SuperLLMProvider)? { id == providerID ? self : nil }
    var providerCount: Int { 1 }
    func register(_ provider: any SuperLLMProvider) throws {}
    func unregister(id: String) {}
    var selectedProviderID: String? { providerID }
    var selectedModel: String? { "test-model" }
    func models(for providerID: String) -> [String] { ["test-model"] }
    func select(providerID: String, model: String?, reason: ModelSelectionReason) {}
}
