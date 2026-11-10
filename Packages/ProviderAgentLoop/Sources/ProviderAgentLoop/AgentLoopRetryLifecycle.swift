import Foundation

/// 自动重试的生命周期事件。
///
/// 供必须与重试共享回合生命周期的上层桥接器（如 ACP）使用：
/// 一次可重试的 `.failed` 并不等于回合结束，真正的终态要等重试链收敛。
@MainActor
public enum AgentLoopRetryLifecycleEvent: Sendable, Equatable {
    /// 已为该会话调度一次重试（可能仍在退避等待）。
    case scheduled(conversationID: UUID, attempt: Int)
    /// 重试链结束且未恢复：预算耗尽、失败不可重试、重试请求被拒绝。
    case gaveUp(conversationID: UUID, reason: String)
}

/// 重试生命周期观察句柄。
@MainActor
public protocol AgentLoopRetryLifecycleObserverHandle: AnyObject {
    /// 停止接收后续事件。重复调用无副作用。
    func cancel()
}

/// 自动重试的生命周期查询与订阅。
///
/// 未装配重试插件时内核解析不到该 Provider，调用方应退化为「没有重试接管」。
@MainActor
public protocol AgentLoopRetryLifecycleProviding: AnyObject {
    /// 该会话当前是否有自动重试已调度或正在执行。
    func isRetrying(conversationID: UUID) -> Bool

    /// 主动终止该会话的待执行重试（不影响正在运行的回合）。
    func cancelRetry(for conversationID: UUID)

    /// 订阅重试生命周期事件；回调在主线程同步执行。
    func addRetryLifecycleObserver(
        _ callback: @escaping (AgentLoopRetryLifecycleEvent) -> Void
    ) -> any AgentLoopRetryLifecycleObserverHandle
}
