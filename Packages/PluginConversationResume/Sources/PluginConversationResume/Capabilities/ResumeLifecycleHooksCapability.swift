import Foundation
import ProviderLifecycleHooks

/// 「继续」功能所需的最小生命周期钩子能力。
///
/// 收窄自 `LifecycleHooksProviding`：本功能只关心「回合开始」与「回合结束」
/// 两个时刻，不需要其它钩子点，也不应该让协调器看到完整 Provider 接口。
@MainActor
protocol ResumeLifecycleHooksCapability: AnyObject {
    /// 注册「回合开始」钩子。
    ///
    /// 钩子会被 `await`，因此实现方必须**同步完成持久化写入**，
    /// 不能把写入推迟到后台任务里。
    func onTurnStarted(_ hook: @escaping (ResumeTurnEvent) async -> Void)

    /// 注册「回合结束」钩子。
    func onTurnFinished(_ hook: @escaping (ResumeTurnEvent) async -> Void)
}

/// 插件自有的回合事件，不泄漏 `TurnLifecycleContext`。
struct ResumeTurnEvent: Sendable {
    /// 会话 ID。
    let conversationID: UUID
    /// 回合 ID。
    let turnID: UUID
    /// 回合结束原因（仅「回合结束」时有值）。
    let endReason: ResumeTurnEndReason?
}

/// 回合结束原因。
enum ResumeTurnEndReason: String, Sendable {
    case completed
    case failed
    case cancelled
    case suspended
}

/// 将内核 `LifecycleHooksProviding` 收窄为「继续」功能所需的能力。
@MainActor
final class ResumeLifecycleHooksCapabilityAdapter: ResumeLifecycleHooksCapability {
    private let hooks: any LifecycleHooksProviding

    init(hooks: any LifecycleHooksProviding) {
        self.hooks = hooks
    }

    func onTurnStarted(_ hook: @escaping (ResumeTurnEvent) async -> Void) {
        hooks.addTurnStartedHook { context in
            await hook(
                ResumeTurnEvent(
                    conversationID: context.conversationID,
                    turnID: context.turnID,
                    endReason: nil
                )
            )
        }
    }

    func onTurnFinished(_ hook: @escaping (ResumeTurnEvent) async -> Void) {
        hooks.addTurnFinishedHook { context in
            await hook(
                ResumeTurnEvent(
                    conversationID: context.conversationID,
                    turnID: context.turnID,
                    endReason: context.endReason.map { reason in
                        switch reason {
                        case .completed: return .completed
                        case .failed: return .failed
                        case .cancelled: return .cancelled
                        case .suspended: return .suspended
                        }
                    }
                )
            )
        }
    }
}
