import Foundation
import KernelCore
import KitAgentTool
import ProviderAgentLoop
import ProviderConversation
import ProviderDeveloperMode
import ProviderLifecycleHooks
import ProviderMessage
import ProviderMessageRendering
import ProviderToolManager
import SwiftUI
import Testing
@testable import PluginMessageRenderer

/// 消息行右键「停止」功能的判定与接线测试。
///
/// 「停止」是消息行上唯一一个会**改变全局会话状态**的右键项：
/// 它停掉的是该消息**所属会话**的 Agent 回合。因此两个性质必须锁死：
///
/// 1. **可见性判定**：只在回合 running / suspended 时出现。
///    空闲时显示一个点了没反应的按钮，比不显示更糟。
/// 2. **接线正确**：停止的是消息自己的会话，不是当前选中会话。
///    用户浏览历史会话时右键历史消息，停的必须是那个历史会话。
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

/// 记录停止请求的最小能力替身。
@MainActor
private final class StopRecordingCapability: MessageRendererCapability {
    /// 可停止的会话集合。
    var stoppableConversationIDs: Set<UUID> = []
    /// 被调用 `stopTurn` 的会话。
    private(set) var stoppedConversations: [UUID] = []

    func canStopTurn(conversationID: UUID) -> Bool {
        stoppableConversationIDs.contains(conversationID)
    }

    func stopTurn(conversationID: UUID) {
        stoppedConversations.append(conversationID)
    }

    // MARK: 未使用的协议成员

    func toolCallResult(
        for toolCallID: String,
        conversationID: UUID,
        turnID: UUID?
    ) async -> ToolCallResult? {
        nil
    }

    func resendMessage(content: String, conversationID: UUID) async {}

    func canRetryTurn(turnID: UUID, conversationID: UUID) -> Bool { false }

    func retryTurn(turnID: UUID, conversationID: UUID) async {}

    func toolCallRenderer(for toolCall: ToolCall) -> (any ToolCallRowRenderer)? { nil }

    func makeToolJobActivityModel(
        toolCallID: String,
        conversationID: UUID,
        turnID: UUID?
    ) -> ToolJobActivityModel {
        ToolJobActivityModel(
            manager: nil,
            toolCallID: toolCallID,
            conversationID: conversationID,
            turnID: turnID
        )
    }

    var isDeveloperModeEnabled: Bool { false }

    func addDeveloperModeObserver(
        _ callback: @escaping (DeveloperModeProvidingEvent) -> Void
    ) -> any DeveloperModeProvidingObserverHandle {
        NoopDeveloperModeProvidingObserverHandle()
    }
}

@Suite("消息右键停止：可见性判定")
@MainActor
struct MessageContextMenuStopVisibilityTests {

    private func message(role: MessageRole = .user, conversationID: UUID = UUID()) -> Message {
        Message(
            conversationID: conversationID,
            role: role,
            content: "hello"
        )
    }

    @Test("回合 running 时可停止")
    func canStopWhileRunning() {
        let conversationID = UUID()
        let capability = StopRecordingCapability()
        capability.stoppableConversationIDs = [conversationID]

        let target = message(conversationID: conversationID)
        #expect(MessageContextMenu.canStop(message: target, capability: capability))
    }

    @Test("回合 suspended 时也可停止")
    func canStopWhileSuspended() {
        // 挂在等工具授权 / 等用户回答的回合同样是「没干完的活」，
        // 用户需要能把它停掉，而不是把对话晾在那里干等。
        let conversationID = UUID()
        let capability = StopRecordingCapability()
        capability.stoppableConversationIDs = [conversationID]

        let target = message(role: .assistant, conversationID: conversationID)
        #expect(MessageContextMenu.canStop(message: target, capability: capability))
    }

    @Test("回合空闲 / 已完成 / 已失败 / 已取消时不可停止")
    func cannotStopWhenNoActiveTurn() {
        let capability = StopRecordingCapability()
        let target = message()

        #expect(!MessageContextMenu.canStop(message: target, capability: capability))
    }

    @Test("缺少能力时不可停止")
    func cannotStopWithoutCapability() {
        let target = message()
        #expect(!MessageContextMenu.canStop(message: target, capability: nil))
    }

    @Test("可停止性与消息角色无关")
    func stopVisibilityIsIndependentOfMessageRole() {
        // 助手消息、工具消息同样可能属于一个正在跑的会话。
        let conversationID = UUID()
        let capability = StopRecordingCapability()
        capability.stoppableConversationIDs = [conversationID]

        for role in [MessageRole.user, .assistant, .tool, .system, .status, .error] {
            let target = message(role: role, conversationID: conversationID)
            #expect(
                MessageContextMenu.canStop(message: target, capability: capability),
                "role \(role.rawValue) 不应影响可停止性"
            )
        }
    }
}

@Suite("消息右键停止：能力层接线")
@MainActor
struct MessageRendererCapabilityStopTests {

    private func makeKernel(with agentLoop: StubAgentLoopProvider) throws -> KernelCoreContainer {
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any MessageRenderingProviding).self, DefaultMessageRenderingProviding())
        try kernel.registerProvider((any AgentLoopProviding).self, agentLoop)
        return kernel
    }

    @Test("running 与 suspended 都判定为可停止")
    func canStopTurnReflectsRunningAndSuspended() throws {
        let agentLoop = StubAgentLoopProvider()
        let kernel = try makeKernel(with: agentLoop)
        let capability = MessageRendererCapabilityAdapter(kernel: kernel)

        let conversationID = UUID()

        agentLoop.states[conversationID] = .running
        #expect(capability.canStopTurn(conversationID: conversationID))

        agentLoop.states[conversationID] = .suspended
        #expect(capability.canStopTurn(conversationID: conversationID))
    }

    @Test("其余回合状态都判定为不可停止")
    func canStopTurnIsFalseForTerminalStates() throws {
        let agentLoop = StubAgentLoopProvider()
        let kernel = try makeKernel(with: agentLoop)
        let capability = MessageRendererCapabilityAdapter(kernel: kernel)

        let conversationID = UUID()
        for state in [AgentLoopState.idle, .completed, .failed, .cancelled] {
            agentLoop.states[conversationID] = state
            #expect(
                !capability.canStopTurn(conversationID: conversationID),
                "state \(state.rawValue) 不应可停止"
            )
        }
    }

    @Test("停止动作取消的是消息所属会话的回合")
    func stopTurnCancelsTheGivenConversation() throws {
        let agentLoop = StubAgentLoopProvider()
        let kernel = try makeKernel(with: agentLoop)
        let capability = MessageRendererCapabilityAdapter(kernel: kernel)

        let conversationID = UUID()
        agentLoop.states[conversationID] = .running

        capability.stopTurn(conversationID: conversationID)

        #expect(agentLoop.cancelledConversations == [conversationID])
    }

    @Test("停止后回合状态变为 cancelled")
    func stopTurnLeavesCancelledState() throws {
        let agentLoop = StubAgentLoopProvider()
        let kernel = try makeKernel(with: agentLoop)
        let capability = MessageRendererCapabilityAdapter(kernel: kernel)

        let conversationID = UUID()
        agentLoop.states[conversationID] = .running

        capability.stopTurn(conversationID: conversationID)

        #expect(agentLoop.state(for: conversationID) == .cancelled)
        #expect(!capability.canStopTurn(conversationID: conversationID))
    }

    @Test("缺少 AgentLoop Provider 时安全降级")
    func degradesGracefullyWithoutAgentLoop() throws {
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any MessageRenderingProviding).self, DefaultMessageRenderingProviding())
        let capability = MessageRendererCapabilityAdapter(kernel: kernel)

        let conversationID = UUID()
        #expect(!capability.canStopTurn(conversationID: conversationID))
        // 不应崩溃。
        capability.stopTurn(conversationID: conversationID)
    }
}

@Suite("消息右键停止：使用消息自身的会话")
@MainActor
struct MessageContextMenuUsesOwnConversationTests {

    @Test("停止的是消息自己的 conversationID，而非当前选中会话")
    func stopsOwnConversationNotSelectedOne() throws {
        let agentLoop = StubAgentLoopProvider()
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any MessageRenderingProviding).self, DefaultMessageRenderingProviding())
        try kernel.registerProvider((any AgentLoopProviding).self, agentLoop)

        let capability = MessageRendererCapabilityAdapter(kernel: kernel)

        // 用户正在浏览历史会话 B，而右键的是历史会话 A 的消息。
        let messageConversationID = UUID()
        let selectedConversationID = UUID()
        agentLoop.states[messageConversationID] = .running

        let target = Message(
            conversationID: messageConversationID,
            role: .assistant,
            content: "历史消息"
        )

        #expect(MessageContextMenu.canStop(message: target, capability: capability))

        capability.stopTurn(conversationID: target.conversationID)

        #expect(agentLoop.cancelledConversations == [messageConversationID])
        #expect(!agentLoop.cancelledConversations.contains(selectedConversationID))
    }
}

@Suite("消息右键菜单：重新发送的可见性")
@MainActor
struct MessageContextMenuResendVisibilityTests {

    private func message(role: MessageRole, content: String) -> Message {
        Message(conversationID: UUID(), role: role, content: content)
    }

    @Test("用户消息且有正文时提供重新发送")
    func resendAvailableForUserMessage() {
        let capability = StopRecordingCapability()
        let menu = MessageContextMenu(
            capability: capability,
            message: message(role: .user, content: "hi")
        )
        #expect(menu.showsResend)
    }

    @Test("非用户消息不提供重新发送")
    func resendHiddenForNonUserMessages() {
        let capability = StopRecordingCapability()
        for role in [MessageRole.assistant, .tool, .system, .status, .error] {
            let menu = MessageContextMenu(
                capability: capability,
                message: message(role: role, content: "hi")
            )
            #expect(!menu.showsResend, "role \(role.rawValue) 不应提供重新发送")
        }
    }

    @Test("空正文不提供重新发送")
    func resendHiddenForEmptyContent() {
        let capability = StopRecordingCapability()
        let menu = MessageContextMenu(
            capability: capability,
            message: message(role: .user, content: "")
        )
        #expect(!menu.showsResend)
    }

    @Test("缺少能力时不提供重新发送")
    func resendHiddenWithoutCapability() {
        let menu = MessageContextMenu(
            capability: nil,
            message: message(role: .user, content: "hi")
        )
        #expect(!menu.showsResend)
    }
}
