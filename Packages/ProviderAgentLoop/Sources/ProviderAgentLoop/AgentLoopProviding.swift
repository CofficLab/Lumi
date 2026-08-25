import Foundation
import KitLLM
import ProviderConversation
import ProviderLifecycleHooks
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager

/// Agent 回合管理。
///
/// 防并发 runTurn、流式 LLM 调用、工具执行与授权暂停/恢复、错误落库、取消。
/// 依赖通过构造注入：
/// - `MessageManaging`（构造注入，消息历史与落库）
/// - `llmManager` / `toolManager` / `streaming` / `conversations`（构造注入）
@MainActor
public protocol AgentLoopProviding: AnyObject, ObservableObject {
    /// 注册回合生命周期观察者。
    @discardableResult
    func addAgentLoopObserver(
        _ callback: @escaping (AgentLoopEvent) -> Void
    ) -> any AgentLoopObserverHandle
    func runTurn(in conversationID: UUID) async throws -> AgentLoopOutcome
    func resumeTurn(in conversationID: UUID, request: AgentTurnResumeRequest) async throws -> AgentLoopOutcome
    func cancelTurn(in conversationID: UUID)
    func state(for conversationID: UUID) -> AgentLoopState
    /// 当前（或最近一次）暂停的详情；无暂停时返回 `nil`。
    func suspension(for conversationID: UUID) -> AgentLoopSuspension?
    func isRunning(for conversationID: UUID) -> Bool
    func currentTurnID(for conversationID: UUID) -> UUID?

    /// 注入生命周期钩子管理器，回合循环在各关键节点触发对应钩子。
    func setLifecycleHooks(_ hooks: (any LifecycleHooksProviding)?)
}
