import Foundation
import KernelCore
import KitAgentTool
import ProviderAgentLoop
import ProviderConversation
import ProviderLifecycleHooks
import ProviderToolManager
import Testing
@testable import PluginMessageRenderer

/// 复现 #1028：Brief 模式停止回合后，旧授权卡仍可执行高风险工具。
///
/// 两个独立缺口：
/// 1. 底部固定授权卡由 `RiskApprovalChatViewModel.pendingApprovals` 缓存驱动。
///    Stop 只改写持久化占位，不发 ToolManager 完成事件，缓存里的卡片不会消失。
///    现由 AgentLoop 终态事件清理。
/// 2. `ToolApprovalBridge.resolve` 直接调用 `executeAuthorized`，不校验回合是否
///    仍然活着。现由 `isAuthorizationStillActive` 在提交前拦截。
@Suite("授权卡片取消失效", .serialized)
@MainActor
struct ToolApprovalCancellationTests {

    // MARK: - 展示层缓存

    @Test("Stop 后底部授权缓存立即失效")
    func cancelledTurnClearsPendingApproval() {
        let conversationID = UUID()
        let turnID = UUID()
        let toolManager = StubToolManager()
        let agentLoop = StubAgentLoop()
        let viewModel = RiskApprovalChatViewModel(
            conversations: DefaultConversationManager(),
            toolManager: toolManager,
            agentLoop: agentLoop
        )
        defer { viewModel.cancel() }

        viewModel.consume(.authorizationRequired(
            conversationID: conversationID,
            turnID: turnID,
            toolCall: ToolCall(id: "call-stop", name: "write", arguments: "{}")
        ))
        #expect(viewModel.pendingApprovals[conversationID]?.toolCall.id == "call-stop")

        agentLoop.emit(.cancelled(conversationID: conversationID, turnID: turnID))

        #expect(viewModel.pendingApprovals[conversationID] == nil)
    }

    @Test("完成与失败同样清理待授权缓存")
    func terminalEventsClearPendingApproval() {
        let conversationID = UUID()
        let toolManager = StubToolManager()

        for (index, event) in [
            AgentLoopEvent.completed(conversationID: conversationID, turnID: UUID()),
            .failed(conversationID: conversationID, turnID: UUID(), reason: "boom"),
        ].enumerated() {
            let agentLoop = StubAgentLoop()
            let viewModel = RiskApprovalChatViewModel(
                conversations: DefaultConversationManager(),
                toolManager: toolManager,
                agentLoop: agentLoop
            )
            let turnID: UUID
            switch event {
            case let .completed(_, id), let .failed(_, id, _):
                turnID = id
            default:
                Issue.record("unexpected event")
                viewModel.cancel()
                continue
            }
            viewModel.consume(.authorizationRequired(
                conversationID: conversationID,
                turnID: turnID,
                toolCall: ToolCall(id: "call-\(index)", name: "write", arguments: "{}")
            ))
            agentLoop.emit(event)
            #expect(viewModel.pendingApprovals[conversationID] == nil)
            viewModel.cancel()
        }
    }

    @Test("迟到的旧回合终态不会误删新回合授权")
    func staleTerminalEventKeepsNewerTurnApproval() {
        let conversationID = UUID()
        let newTurnID = UUID()
        let agentLoop = StubAgentLoop()
        let viewModel = RiskApprovalChatViewModel(
            conversations: DefaultConversationManager(),
            toolManager: StubToolManager(),
            agentLoop: agentLoop
        )
        defer { viewModel.cancel() }

        viewModel.consume(.authorizationRequired(
            conversationID: conversationID,
            turnID: newTurnID,
            toolCall: ToolCall(id: "call-new", name: "write", arguments: "{}")
        ))
        agentLoop.emit(.cancelled(conversationID: conversationID, turnID: UUID()))

        #expect(viewModel.pendingApprovals[conversationID]?.toolCall.id == "call-new")
    }

    // MARK: - 执行边界

    @Test("停止的回合点击允许不会执行工具")
    func cancelledTurnRefusesAllow() async throws {
        let conversationID = UUID()
        let manager = StubToolManager()
        let agentLoop = StubAgentLoop()
        agentLoop.stateValue = .cancelled
        try activateBridge(toolManager: manager, agentLoop: agentLoop)
        defer { ToolApprovalBridge.shared.stop() }

        await ToolApprovalBridge.shared.performResolve(
            conversationID: conversationID,
            toolCall: ToolCall(id: "call-cancelled", name: "run_command", arguments: "{}"),
            answer: "允许"
        )

        #expect(manager.authorizedCalls.isEmpty)
        #expect(manager.rejectedCalls.isEmpty)
    }

    @Test("已结束或失败的回合同样拒绝执行")
    func terminalTurnsRefuseExecution() async throws {
        for state in [AgentLoopState.completed, .failed] {
            let manager = StubToolManager()
            let agentLoop = StubAgentLoop()
            agentLoop.stateValue = state
            try activateBridge(toolManager: manager, agentLoop: agentLoop)
            defer { ToolApprovalBridge.shared.stop() }

            await ToolApprovalBridge.shared.performResolve(
                conversationID: UUID(),
                toolCall: ToolCall(id: "call-\(state.rawValue)", name: "run_command", arguments: "{}"),
                answer: "允许"
            )

            #expect(manager.authorizedCalls.isEmpty)
        }
    }

    @Test("挂起指向其他工具时旧卡片不得执行")
    func mismatchedSuspensionRefusesExecution() async throws {
        let conversationID = UUID()
        let manager = StubToolManager()
        let agentLoop = StubAgentLoop()
        agentLoop.stateValue = .suspended
        agentLoop.suspensionValue = AgentLoopSuspension(
            suspensionID: "userInput:current-call",
            conversationID: conversationID,
            toolCallID: "current-call",
            kind: "userInput",
            payload: "{}"
        )
        try activateBridge(toolManager: manager, agentLoop: agentLoop)
        defer { ToolApprovalBridge.shared.stop() }

        await ToolApprovalBridge.shared.performResolve(
            conversationID: conversationID,
            toolCall: ToolCall(id: "stale-call", name: "run_command", arguments: "{}"),
            answer: "允许"
        )

        #expect(manager.authorizedCalls.isEmpty)
    }

    @Test("挂起匹配时正常执行")
    func matchingSuspensionExecutes() async throws {
        let conversationID = UUID()
        let manager = StubToolManager()
        let agentLoop = StubAgentLoop()
        agentLoop.stateValue = .suspended
        agentLoop.suspensionValue = AgentLoopSuspension(
            suspensionID: "userInput:approval-call",
            conversationID: conversationID,
            toolCallID: "approval-call",
            kind: "userInput",
            payload: "{}"
        )
        try activateBridge(toolManager: manager, agentLoop: agentLoop)
        defer { ToolApprovalBridge.shared.stop() }

        await ToolApprovalBridge.shared.performResolve(
            conversationID: conversationID,
            toolCall: ToolCall(id: "approval-call", name: "run_command", arguments: "{}"),
            answer: "允许"
        )

        #expect(manager.authorizedCalls.map(\.id) == ["approval-call"])
    }

    @Test("应用重启后的 idle 回合仍允许授权")
    func idleTurnStillAllowsRestartApproval() async throws {
        let manager = StubToolManager()
        let agentLoop = StubAgentLoop()
        agentLoop.stateValue = .idle
        try activateBridge(toolManager: manager, agentLoop: agentLoop)
        defer { ToolApprovalBridge.shared.stop() }

        await ToolApprovalBridge.shared.performResolve(
            conversationID: UUID(),
            toolCall: ToolCall(id: "restored-call", name: "write", arguments: "{}"),
            answer: "允许"
        )

        #expect(manager.authorizedCalls.map(\.id) == ["restored-call"])
    }

    @Test("未提供 AgentLoop 时保持旧行为")
    func missingAgentLoopKeepsLegacyBehavior() async throws {
        let manager = StubToolManager()
        try activateBridge(toolManager: manager, agentLoop: nil)
        defer { ToolApprovalBridge.shared.stop() }

        await ToolApprovalBridge.shared.performResolve(
            conversationID: UUID(),
            toolCall: ToolCall(id: "legacy-call", name: "write", arguments: "{}"),
            answer: "允许"
        )

        #expect(manager.authorizedCalls.map(\.id) == ["legacy-call"])
    }

    private func activateBridge(
        toolManager: StubToolManager,
        agentLoop: StubAgentLoop?
    ) throws {
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any ToolManagerProviding).self, toolManager)
        if let agentLoop {
            try kernel.registerProvider((any AgentLoopProviding).self, agentLoop)
        }
        ToolApprovalBridge.shared.start(kernel: kernel)
    }
}

// MARK: - Test Doubles

@MainActor
private final class StubToolManager: ToolManagerProviding {
    private(set) var authorizedCalls: [ToolCall] = []
    private(set) var rejectedCalls: [ToolCall] = []

    func addToolManagerObserver(
        _ callback: @escaping (ToolManagerEvent) -> Void
    ) -> any ToolManagerObserverHandle {
        NoopHandle()
    }

    func addToolJobObserver(
        _ callback: @escaping (ToolJobEvent) -> Void
    ) -> any ToolJobObserverHandle {
        NoopHandle()
    }

    func allTools() -> [any SuperAgentTool] { [] }
    func add(_ tool: any SuperAgentTool, pluginID: String) {}
    func remove(id: String) {}
    func toolsGroupedByPlugin() -> [(pluginID: String, tools: [any SuperAgentTool])] { [] }
    func tool(named name: String) -> (any SuperAgentTool)? { nil }
    func displayDescription(for toolCall: ToolCall) -> String? { nil }
    func riskLevel(for toolCall: ToolCall) -> CommandRiskLevel? { nil }

    func execute(
        _ toolCall: ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult {
        ToolCallResult(content: "unused")
    }

    func executeAuthorized(
        _ toolCall: ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult {
        authorizedCalls.append(toolCall)
        return ToolCallResult(content: "executed")
    }

    func rejectAuthorized(
        _ toolCall: ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult {
        rejectedCalls.append(toolCall)
        return ToolCallResult(content: "rejected", isError: true)
    }

    func toolCalls(for turnID: UUID) async -> [ToolCallRecord] { [] }
    func toolCallResult(for toolCallID: String) async -> ToolCallResult? { nil }
    func deleteToolCalls(for conversationID: UUID) async {}
}

@MainActor
private final class StubAgentLoop: AgentLoopProviding {
    var stateValue: AgentLoopState = .idle
    var suspensionValue: AgentLoopSuspension?
    private var observers: [UUID: (AgentLoopEvent) -> Void] = [:]

    func addAgentLoopObserver(
        _ callback: @escaping (AgentLoopEvent) -> Void
    ) -> any AgentLoopObserverHandle {
        let id = UUID()
        observers[id] = callback
        return StubObserverHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    func emit(_ event: AgentLoopEvent) {
        for callback in observers.values {
            callback(event)
        }
    }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome {
        throw AgentLoopError.invalidResumeRequest
    }

    func resumeTurn(
        in conversationID: UUID,
        request: AgentTurnResumeRequest
    ) async throws -> AgentLoopOutcome {
        throw AgentLoopError.invalidResumeRequest
    }

    func cancelTurn(in conversationID: UUID) {}
    func state(for conversationID: UUID) -> AgentLoopState { stateValue }
    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { suspensionValue }
    func isRunning(for conversationID: UUID) -> Bool { stateValue == .running }
    func currentTurnID(for conversationID: UUID) -> UUID? { nil }
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}
}

@MainActor
private final class NoopHandle: ToolManagerObserverHandle, ToolJobObserverHandle {
    func cancel() {}
}

@MainActor
private final class StubObserverHandle: AgentLoopObserverHandle {
    private let onCancel: () -> Void

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        onCancel()
    }
}
