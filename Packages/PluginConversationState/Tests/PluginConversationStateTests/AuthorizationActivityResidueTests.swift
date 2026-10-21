import Foundation
import KitAgentTool
import ProviderAgentLoop
import ProviderConversationState
import ProviderToolManager
import Testing
@testable import PluginConversationState

/// 复现「授权已解决，但 activity 仍停在 `waitingForUser`」的问题。
///
/// 用户报告的现象：对话卡在「等待你的输入…」，但界面上**没有任何卡片**可以回答。
///
/// # 真实机制（取自磁盘日志与消息库，2026-10-21 15:50:02 ~ 15:53:08）
///
/// 1. `edit_file`（`.high` 风险）触发 `authorizationRequired`
///    → `ToolManagerStateObserver` 把 activity 设成 `.waitingForUser`
/// 2. 用户按下停止 → AgentLoop 发出 `.cancelled` → activity 被清空
/// 3. 授权占位被写成 `userRejected` + 终态结果 → **授权卡片不再渲染**
/// 4. 但 activity 仍停在 `.waitingForUser` → UI 永远显示「等待你的输入…」
///
/// # 为什么 Job 事件救不了场
///
/// 这是本次排查最关键的一点：**授权等待的调用根本不创建 Tool Job**。
///
/// 证据：`tool_jobs.sqlite` 里查不到 `call_3c8c5a1f69f74100a29294ae`
/// （就是那次触发授权的 `edit_file`），而同一批次的其它调用都有记录。
///
/// 原因在 `ToolCallsObserver`：需要授权的调用走
/// `executeLegacyBatch(inputs, policy: .requireApprovalForHighRisk, ...)`，
/// 它既不调用 `submit(...)`（那才是创建 Job 的入口），也不会产生任何
/// `ToolJobEvent`。而 `ToolManagerStateObserver` 的清理逻辑
/// （`clearActivity: !hasRunning && !isWaiting`）**只挂在 job 事件上**。
///
/// 于是：
/// - 写入 `waitingForUser` 的路径有两条（`authorizationRequired` + job 事件）
/// - 清理 `waitingForUser` 的路径只有一条（job 事件）
/// - 授权路径根本不产生 job 事件 → **清理路径永不触发**
///
/// 死锁的成因：提示说有东西在等你，但等待的东西已经不存在了。
///
/// # 与 Provider 不变量的关系
///
/// `ConversationStateProvider` 已保证「终态回合不承载 activity」。但授权路径还有
/// 一个**独立**的问题：回合此时仍是 `.suspended`（活着，只是在等用户），
/// Provider 的守卫不会、也不该拦它。因此 `ToolManagerStateObserver` 仍必须
/// 在 `authorizedCompleted` 时主动把 activity 从「等待用户」里摘出来。
@Suite("授权解决后 activity 残留")
struct AuthorizationActivityResidueTests {

    @Test("授权完成后 activity 不得停留在 waitingForUser")
    @MainActor
    func activityClearedAfterAuthorizationResolved() {
        let scenario = SuspendedAuthorizationScenario(toolCallID: "call_edit_1", file: "/tmp/a.swift")

        // 授权完成事件到达。
        //
        // - Important: 这里**不**发任何 job 事件。真实链路里授权路径
        //   根本不创建 Job（见类型注释），因此 `authorizedCompleted` 是
        //   唯一可能清理 activity 的事件。
        scenario.toolManager.emit(.authorizedCompleted(
            conversationID: scenario.conversationID,
            turnID: scenario.turnID,
            toolCall: scenario.toolCall,
            result: ToolCallResult(content: "ok")
        ))

        let snapshot = scenario.provider.state(for: scenario.conversationID)
        #expect(snapshot.authorizationState == .none)
        #expect(
            snapshot.activity != .waitingForUser,
            """
            授权已解决，activity 仍停在 waitingForUser。\
            UI 会一直显示「等待你的输入…」，但此时已无任何卡片可回答。\
            授权路径不产生 ToolJobEvent，清理只能靠 authorizedCompleted。
            """
        )
        scenario.observer.cancel()
    }

    @Test("授权被拒后 activity 不得停留在 waitingForUser")
    @MainActor
    func activityClearedAfterAuthorizationRejected() {
        let scenario = SuspendedAuthorizationScenario(toolCallID: "call_edit_2", file: "/tmp/b.swift")

        // 用户点「拒绝」：工具不执行，回合继续走后续推理。
        scenario.toolManager.emit(.authorizedCompleted(
            conversationID: scenario.conversationID,
            turnID: scenario.turnID,
            toolCall: scenario.toolCall,
            result: ToolCallResult(content: "Tool execution was rejected by the user.", isError: true)
        ))

        let snapshot = scenario.provider.state(for: scenario.conversationID)
        #expect(snapshot.authorizationState == .none)
        #expect(
            snapshot.activity != .waitingForUser,
            "授权被拒后 activity 仍停在 waitingForUser，用户会看到永不消失的「等待你的输入…」"
        )
        scenario.observer.cancel()
    }

    @Test("授权请求不产生 ToolJobEvent 时仍必须能清掉 activity")
    @MainActor
    func activityClearedWithoutAnyToolJobEvent() {
        let scenario = SuspendedAuthorizationScenario(toolCallID: "call_edit_3", file: "/tmp/c.swift")

        // 授权完成——**全程没有任何 ToolJobEvent**。
        //
        // 这条用例显式钉住「授权路径不依赖 Job」这个事实：
        // 若将来实现改成依赖 job 事件清理 activity，这条会立刻失败。
        scenario.toolManager.emit(.authorizedCompleted(
            conversationID: scenario.conversationID,
            turnID: scenario.turnID,
            toolCall: scenario.toolCall,
            result: ToolCallResult(content: "ok")
        ))

        #expect(
            scenario.provider.state(for: scenario.conversationID).activity != .waitingForUser,
            "授权路径没有 ToolJobEvent，activity 只能由 authorizedCompleted 清理"
        )
        scenario.observer.cancel()
    }

    @Test("授权请求时回合已挂起，activity 才得以写入")
    @MainActor
    func authorizationRequestLandsOnSuspendedTurn() {
        let scenario = SuspendedAuthorizationScenario(toolCallID: "call_edit_0", file: "/tmp/a.swift")

        let snapshot = scenario.provider.state(for: scenario.conversationID)
        #expect(snapshot.agentLoopState == .suspended)
        #expect(snapshot.activity == .waitingForUser)
        #expect(snapshot.authorizationState == .required)
        scenario.observer.cancel()
    }

    @Test("回合取消后迟到的 Job 事件不得把 activity 改回 waitingForUser")
    @MainActor
    func lateJobEventDoesNotRestoreWaitingForUserAfterCancellation() {
        let conversationID = UUID()
        let turnID = UUID()
        let call = ToolCall(
            id: "call_edit_4",
            name: "edit_file",
            arguments: "{\"file_path\":\"/tmp/d.swift\"}"
        )

        let toolManager = TestToolManager()
        let provider = ConversationStateProvider()
        let observer = ToolManagerStateObserver(toolManager: toolManager, provider: provider)

        // 1. 回合挂起 → activity = waitingForUser。
        provider.update(
            conversationID: conversationID,
            turnID: turnID,
            agentLoopState: .suspended,
            activity: .waitingForUser
        )
        #expect(provider.state(for: conversationID).activity == .waitingForUser)

        // 2. 工具 Job 进入非终态。
        var job = ToolJob(
            conversationID: conversationID,
            turnID: turnID,
            toolCall: call,
            status: .running
        )
        toolManager.emitJob(.started(job))

        // 3. 用户按下停止：AgentLoop 发出 `.cancelled`，activity 应被清空。
        provider.update(
            conversationID: conversationID,
            turnID: turnID,
            agentLoopState: .cancelled,
            toolState: .completed,
            authorizationState: .none,
            clearActivity: true
        )
        #expect(provider.state(for: conversationID).activity == nil)

        // 4. 迟到的 Job 终态事件到达，不得把已终结的回合拖回「等待用户」。
        job.status = .cancelled
        toolManager.emitJob(.cancelled(
            jobID: job.id,
            result: ToolCallResult(content: "cancelled", isError: true),
            snapshot: job
        ))

        let snapshot = provider.state(for: conversationID)
        #expect(snapshot.agentLoopState == .cancelled)
        #expect(
            snapshot.activity != .waitingForUser,
            "回合已取消，迟到的 Job 事件却把 activity 改回 waitingForUser"
        )
        observer.cancel()
    }
}

// MARK: - Test Doubles

/// 「回合已挂起，且刚收到一次授权请求」的完整场景。
///
/// 之所以把它做成一个类型而不是每个用例各写一遍：这段前置时序有**顺序要求**
/// （AgentLoop 必须先把回合标记为 `.suspended`，ToolManager 才发
/// `authorizationRequired`）。顺序写反的话，用例会因为 `agentLoopState`
/// 还是 `.idle` 而被 Provider 的守卫拦下，测到的就不是真实路径。
@MainActor
private final class SuspendedAuthorizationScenario {
    let conversationID = UUID()
    let turnID = UUID()
    let toolCall: ToolCall
    let provider = ConversationStateProvider()
    let toolManager = TestToolManager()
    let observer: ToolManagerStateObserver

    init(toolCallID: String, file: String) {
        toolCall = ToolCall(
            id: toolCallID,
            name: "edit_file",
            arguments: "{\"file_path\":\"\(file)\"}"
        )
        observer = ToolManagerStateObserver(toolManager: toolManager, provider: provider)

        // AgentLoop 先把回合挂起。
        provider.update(
            conversationID: conversationID,
            turnID: turnID,
            agentLoopState: .suspended,
            activity: .waitingForUser
        )

        // ToolManager 随后发出授权请求。
        toolManager.emit(.authorizationRequired(
            conversationID: conversationID,
            turnID: turnID,
            toolCall: toolCall
        ))
    }
}

@MainActor
private final class TestToolManager: ToolManagerProviding {
    private var managerCallback: ((ToolManagerEvent) -> Void)?
    private var jobCallback: ((ToolJobEvent) -> Void)?

    func addToolManagerObserver(
        _ callback: @escaping (ToolManagerEvent) -> Void
    ) -> any ToolManagerObserverHandle {
        managerCallback = callback
        return TestToolManagerObserverHandle { [weak self] in
            self?.managerCallback = nil
        }
    }

    func addToolJobObserver(
        _ callback: @escaping (ToolJobEvent) -> Void
    ) -> any ToolJobObserverHandle {
        jobCallback = callback
        return TestToolJobObserverHandle { [weak self] in
            self?.jobCallback = nil
        }
    }

    func emit(_ event: ToolManagerEvent) {
        managerCallback?(event)
    }

    func emitJob(_ event: ToolJobEvent) {
        jobCallback?(event)
    }

    // MARK: Unused protocol requirements

    func submit(
        _ toolCalls: [ToolCall],
        policy: ToolExecutionPolicy,
        conversationID: UUID,
        turnID: UUID?
    ) -> [ToolJob] { [] }

    func allTools() -> [any SuperAgentTool] { [] }
    func add(_ tool: any SuperAgentTool, pluginID: String) {}
    func remove(id: String) {}
    func toolsGroupedByPlugin() -> [(pluginID: String, tools: [any SuperAgentTool])] { [] }
    func tool(named name: String) -> (any SuperAgentTool)? { nil }
    func displayDescription(for toolCall: ToolCall) -> String? { nil }
    func riskLevel(for toolCall: ToolCall) -> CommandRiskLevel? { .high }
    func authorizationDecision(
        for toolCall: ToolCall,
        conversationID: UUID
    ) -> ToolAuthorizationDecision { .requiresUserApproval }
    func execute(
        _ toolCall: ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult { ToolCallResult(content: "") }
    func executeAuthorized(
        _ toolCall: ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult { ToolCallResult(content: "") }
    func rejectAuthorized(
        _ toolCall: ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult { ToolCallResult(content: "") }
    func resolveUserResponse(
        _ answer: String,
        for toolCall: ToolCall,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult { ToolCallResult(content: answer) }
    func executeBatch(
        _ toolCalls: [ToolCall],
        policy: ToolExecutionPolicy,
        conversationID: UUID,
        turnID: UUID?
    ) async -> [BatchToolResult] { [] }
    func toolCalls(for turnID: UUID) async -> [ToolCallRecord] { [] }
    func toolCallResult(for toolCallID: String) async -> ToolCallResult? { nil }
    func deleteToolCalls(for conversationID: UUID) async {}
}

@MainActor
private final class TestToolManagerObserverHandle: ToolManagerObserverHandle {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }
}

@MainActor
private final class TestToolJobObserverHandle: ToolJobObserverHandle {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        cancellation?()
        cancellation = nil
    }
}