import Combine
import Foundation
import KernelCore
import ProviderAgentLoop
import ProviderConversationState
import ProviderToolManager

/// 将会话状态维护能力接入内核。
///
/// 状态逻辑由 `DefaultConversationStateProvider` 负责；插件只负责在所有
/// AgentLoop/ToolManager 替换完成后完成依赖解析、监听建立和 Provider 注册。
@MainActor
public final class ConversationStatePlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.conversation-state"
    public let order = 10
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.conversation-state",
        name: "Conversation State",
        description: "Maintains conversation state from agent and tool events.",
        category: .core,
        stage: .stable,
        policy: .alwaysOn
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let agentLoop = kernel.resolveProvider((any AgentLoopProviding).self),
              let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            return
        }
        let provider = DefaultConversationStateProvider(agentLoop: agentLoop, toolManager: toolManager)
        kernel.unregisterProvider((any ConversationStateProviding).self)
        try kernel.registerProvider((any ConversationStateProviding).self, provider)
    }
}

/// 由插件持有的会话状态实现。
///
/// Provider 包只定义能力契约；事件订阅和状态维护属于本插件的运行时职责。
@MainActor
public final class DefaultConversationStateProvider: ConversationStateProviding {
    @Published public private(set) var states: [UUID: ConversationStateSnapshot] = [:]

    private var agentLoopObserver: (any AgentLoopObserverHandle)?
    private var toolManagerObserver: (any ToolManagerObserverHandle)?

    public init(agentLoop: any AgentLoopProviding, toolManager: any ToolManagerProviding) {
        agentLoopObserver = agentLoop.addAgentLoopObserver { [weak self] event in self?.consume(event) }
        toolManagerObserver = toolManager.addToolManagerObserver { [weak self] event in self?.consume(event) }
    }

    public func state(for conversationID: UUID) -> ConversationStateSnapshot {
        states[conversationID] ?? ConversationStateSnapshot(conversationID: conversationID)
    }

    private func consume(_ event: AgentLoopEvent) {
        switch event {
        case .started(let id, let turn): update(id, turnID: turn, agentLoopState: .running, toolState: .idle, clearError: true)
        case .toolCallsReceived(let id, let turn, _, _), .llmResponseReceived(let id, let turn, _): update(id, turnID: turn, agentLoopState: .running, toolState: .executing)
        case .suspended(let id, let turn, _): update(id, turnID: turn, agentLoopState: .suspended, toolState: .suspended)
        case .completed(let id, let turn): update(id, turnID: turn, agentLoopState: .completed, toolState: .completed)
        case .failed(let id, let turn, let reason): update(id, turnID: turn, agentLoopState: .failed, toolState: .completed, lastError: reason)
        case .cancelled(let id, let turn): update(id, turnID: turn, agentLoopState: .cancelled, toolState: .completed)
        }
    }

    private func consume(_ event: ToolManagerEvent) {
        switch event {
        case .started(let id, let turn, _): update(id, turnID: turn, toolState: .executing)
        case .completed(let id, let turn, _, _), .authorizedCompleted(let id, let turn, _, _): update(id, turnID: turn, toolState: .completed)
        case .batchCompleted(let id, let turn, _, _): update(id, turnID: turn, toolState: .completed)
        }
    }

    private func update(_ id: UUID, turnID: UUID? = nil, agentLoopState: AgentLoopState? = nil, toolState: ConversationToolState? = nil, lastError: String? = nil, clearError: Bool = false) {
        let current = state(for: id)
        states[id] = ConversationStateSnapshot(
            conversationID: id,
            turnID: turnID ?? current.turnID,
            agentLoopState: agentLoopState ?? current.agentLoopState,
            toolState: toolState ?? current.toolState,
            lastError: clearError ? nil : (lastError ?? current.lastError)
        )
    }
}
