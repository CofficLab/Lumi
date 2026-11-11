import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderLifecycleHooks
import Testing
@testable import PluginConversationList

/// 会话行右键「停止当前对话」的判定与接线测试。
///
/// 这个菜单项会**改变全局会话状态**（取消一个回合），因此两条性质必须锁死：
///
/// 1. **可见性判定**：只在回合 running / suspended 时出现。
///    空闲时显示一个点了没反应的按钮，比不显示更糟。
/// 2. **接线正确**：停止的是被右键的那一条会话，不是当前选中会话。
///    用户浏览历史会话时右键历史行，停的必须是那个历史会话。
@MainActor
private final class StubAgentLoopProvider: AgentLoopProviding {
    /// 各会话的回合状态。
    var states: [UUID: AgentLoopState] = [:]
    /// 被调用 `cancelTurn` 的会话。
    private(set) var cancelledConversations: [UUID] = []

    func state(for conversationID: UUID) -> AgentLoopState {
        states[conversationID] ?? .idle
    }

    func cancelTurn(in conversationID: UUID) {
        cancelledConversations.append(conversationID)
        states[conversationID] = .cancelled
    }

    // MARK: 未使用的协议成员

    func addAgentLoopObserver(
        _ callback: @escaping (AgentLoopEvent) -> Void
    ) -> any AgentLoopObserverHandle {
        NoopAgentLoopObserverHandle()
    }

    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome {
        .cancelled
    }

    func resumeTurn(
        in conversationID: UUID,
        request: AgentTurnResumeRequest
    ) async throws -> AgentLoopOutcome {
        .cancelled
    }

    func suspension(for conversationID: UUID) -> AgentLoopSuspension? { nil }
    func lastFailure(for conversationID: UUID) -> AgentLoopFailure? { nil }
    func isRunning(for conversationID: UUID) -> Bool { state(for: conversationID) == .running }
    func currentTurnID(for conversationID: UUID) -> UUID? { nil }
    func isAutoReplySuppressed(for conversationID: UUID) -> Bool { false }
    func setAutoReplySuppressed(_ suppressed: Bool, for conversationID: UUID) {}

    func retryTurn(
        in conversationID: UUID,
        after failedTurnID: UUID
    ) async throws -> AgentLoopOutcome {
        .cancelled
    }

    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?) {}
}

@MainActor
private final class NoopAgentLoopObserverHandle: AgentLoopObserverHandle {
    func cancel() {}
}

@Suite("会话行右键停止：能力层判定")
@MainActor
struct ConversationStopCapabilityTests {

    @Test("running 与 suspended 都判定为可停止")
    func canStopForRunningAndSuspended() {
        let agentLoop = StubAgentLoopProvider()
        let capability = ConversationStopCapabilityAdapter(agentLoop: agentLoop)
        let conversationID = UUID()

        agentLoop.states[conversationID] = .running
        #expect(capability.canStop(conversationID: conversationID))

        agentLoop.states[conversationID] = .suspended
        #expect(capability.canStop(conversationID: conversationID))
    }

    @Test("其余回合状态都判定为不可停止")
    func cannotStopForTerminalStates() {
        let agentLoop = StubAgentLoopProvider()
        let capability = ConversationStopCapabilityAdapter(agentLoop: agentLoop)
        let conversationID = UUID()

        for state in [AgentLoopState.idle, .completed, .failed, .cancelled] {
            agentLoop.states[conversationID] = state
            #expect(
                !capability.canStop(conversationID: conversationID),
                "state \(state.rawValue) 不应可停止"
            )
        }
    }

    @Test("缺少 AgentLoop 时不可停止，且停止是安全的空操作")
    func noAgentLoopMeansNoStop() {
        let capability = ConversationStopCapabilityAdapter(agentLoop: nil)
        let conversationID = UUID()

        #expect(!capability.canStop(conversationID: conversationID))
        // 不应崩溃：没有 Provider 时 stop 就是 no-op。
        capability.stop(conversationID: conversationID)
    }

    @Test("停止动作取消的是指定会话的回合")
    func stopCancelsTheGivenConversation() {
        let agentLoop = StubAgentLoopProvider()
        let capability = ConversationStopCapabilityAdapter(agentLoop: agentLoop)
        let target = UUID()
        let other = UUID()
        agentLoop.states[target] = .running

        capability.stop(conversationID: target)

        #expect(agentLoop.cancelledConversations == [target])
        #expect(
            !agentLoop.cancelledConversations.contains(other),
            "停止不得影响其它会话"
        )
    }
}

@Suite("会话行右键停止：ViewModel 接线")
@MainActor
struct ConversationListStopIntentTests {

    @Test("停止的是被操作的那条会话，而不是当前选中会话")
    func stopTargetsTheGivenConversation() async throws {
        let conversations = DefaultConversationManager()
        let selectedID = try conversations.createConversation(
            title: "Selected", projectPath: nil, providerID: nil, modelName: nil
        )
        let targetID = try conversations.createConversation(
            title: "Target", projectPath: nil, providerID: nil, modelName: nil
        )
        let agentLoop = StubAgentLoopProvider()
        agentLoop.states[targetID] = .running

        let context = ConversationListContext(
            conversations: conversations,
            project: nil,
            agentTurn: agentLoop,
            conversationState: nil,
            chat: nil,
            stopCapability: ConversationStopCapabilityAdapter(agentLoop: agentLoop)
        )
        let viewModel = ConversationListViewModel(
            context: context,
            attentionStore: ConversationAttentionStore(),
            sortStabilizer: ConversationSortStabilizer(),
            scope: .all
        )
        defer { viewModel.cancel() }

        #expect(viewModel.canStopConversation(id: targetID))
        #expect(!viewModel.canStopConversation(id: selectedID))

        viewModel.stopConversation(id: targetID)

        #expect(agentLoop.cancelledConversations == [targetID])
    }

    @Test("未接入停止能力时不会误报可停止")
    func noCapabilityMeansNotStoppable() async throws {
        let conversations = DefaultConversationManager()
        let conversationID = try conversations.createConversation(
            title: "Idle", projectPath: nil, providerID: nil, modelName: nil
        )
        let context = ConversationListContext(
            conversations: conversations,
            project: nil,
            agentTurn: nil,
            conversationState: nil,
            chat: nil
        )
        let viewModel = ConversationListViewModel(
            context: context,
            attentionStore: ConversationAttentionStore(),
            sortStabilizer: ConversationSortStabilizer(),
            scope: .all
        )
        defer { viewModel.cancel() }

        #expect(!viewModel.canStopConversation(id: conversationID))
    }
}
