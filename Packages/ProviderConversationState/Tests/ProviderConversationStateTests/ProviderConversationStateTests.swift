import Foundation
import Testing
import Combine
import KitAgentTool
import ProviderAgentLoop
import ProviderLifecycleHooks
import ProviderToolManager
@testable import ProviderConversationState

@Suite("ProviderConversationState")
@MainActor
struct ProviderConversationStateTests {
    @Test @MainActor
    func unknownConversationStartsIdle() {
        let id = UUID()
        let provider = DefaultConversationStateProvider(agentLoop: AgentLoopSpy(), toolManager: ToolManagerSpy())

        #expect(provider.state(for: id) == ConversationStateSnapshot(conversationID: id))
    }

    @Test @MainActor
    func agentAndToolEventsUpdateTheSameConversationSnapshot() {
        let id = UUID()
        let turnID = UUID()
        let agent = AgentLoopSpy()
        let tools = ToolManagerSpy()
        let provider = DefaultConversationStateProvider(agentLoop: agent, toolManager: tools)

        agent.emit(.started(conversationID: id, turnID: turnID))
        tools.emit(.started(conversationID: id, turnID: turnID, toolCall: .init(id: "1", name: "demo", arguments: "{}")))
        #expect(provider.state(for: id).agentLoopState == .running)
        #expect(provider.state(for: id).toolState == .executing)

        agent.emit(.completed(conversationID: id, turnID: turnID))
        #expect(provider.state(for: id).agentLoopState == .completed)
        #expect(provider.state(for: id).toolState == .completed)
    }
}

@MainActor
private final class AgentLoopSpy: @preconcurrency AgentLoopProviding {
    var objectWillChange = ObservableObjectPublisher()
    private var callback: ((AgentLoopEvent) -> Void)?
    func addAgentLoopObserver(_ callback: @escaping (AgentLoopEvent) -> Void) -> any AgentLoopObserverHandle { self.callback = callback; return Handle() }
    func emit(_ event: AgentLoopEvent) { callback?(event) }
    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome { .completed }
    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome { .completed }
    func cancelTurn(in conversationID: UUID) {}
    func state(for conversationID: UUID) -> AgentLoopState { .idle }
    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }
    func isRunning(for conversationID: UUID) -> Bool { false }
    func currentTurnID(for conversationID: UUID) -> UUID? { nil }
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}
}

@MainActor
private final class ToolManagerSpy: ToolManagerProviding {
    private var callback: ((ToolManagerEvent) -> Void)?
    func addToolManagerObserver(_ callback: @escaping (ToolManagerEvent) -> Void) -> any ToolManagerObserverHandle { self.callback = callback; return Handle() }
    func emit(_ event: ToolManagerEvent) { callback?(event) }
    func allTools() -> [any SuperAgentTool] { [] }
    func add(_ tool: any SuperAgentTool, pluginID: String) {}
    func remove(id: String) {}
    func toolsGroupedByPlugin() -> [(pluginID: String, tools: [any SuperAgentTool])] { [] }
    func tool(named name: String) -> (any SuperAgentTool)? { nil }
    func displayDescription(for toolCall: ToolCall) -> String? { nil }
    func riskLevel(for toolCall: ToolCall) -> CommandRiskLevel? { nil }
    func execute(_ toolCall: ToolCall, conversationID: UUID, turnID: UUID?) async -> ToolCallResult { .init(content: "") }
    func executeAuthorized(_ toolCall: ToolCall, conversationID: UUID, turnID: UUID?) async -> ToolCallResult { .init(content: "") }
    func rejectAuthorized(_ toolCall: ToolCall, conversationID: UUID, turnID: UUID?) async -> ToolCallResult { .init(content: "") }
    func resolveUserResponse(_ answer: String, for toolCall: ToolCall, conversationID: UUID, turnID: UUID?) async -> ToolCallResult { .init(content: "") }
    func executeBatch(_ toolCalls: [ToolCall], policy: ToolExecutionPolicy, conversationID: UUID, turnID: UUID?) async -> [BatchToolResult] { [] }
    func toolCalls(for turnID: UUID) async -> [ToolCallRecord] { [] }
    func toolCallResult(for toolCallID: String) async -> ToolCallResult? { nil }
    func deleteToolCalls(for conversationID: UUID) async {}
}

@MainActor private final class Handle: AgentLoopObserverHandle, ToolManagerObserverHandle { func cancel() {} }
