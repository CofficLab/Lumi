import Foundation
import ProviderLifecycleHooks
import ProviderLLMContext

/// `turnFinished` 钩子：回合完成后触发后台摘要刷新。
///
/// 仅在回合 `completed` 时调度压缩；失败 / 取消 / 挂起不触发。
@MainActor
final class LLMContextTurnFinishedHook {
    private weak var provider: LLMContextProvider?

    init(provider: LLMContextProvider?) {
        self.provider = provider
    }

    func apply(to context: TurnLifecycleContext) {
        guard context.endReason == .completed else { return }
        provider?.scheduleBackgroundCompaction(for: context.conversationID)
    }
}
