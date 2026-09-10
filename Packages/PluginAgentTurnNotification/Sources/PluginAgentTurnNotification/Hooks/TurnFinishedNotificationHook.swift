import Foundation
import ProviderLifecycleHooks

/// 回合结束系统通知钩子：在 `turnFinished` 时按结束原因发送应用通知。
///
/// - `isActive` 在插件关闭后返回 `false`，钩子不再发送通知；
/// - `notifier` 为通知发送器（测试可注入 no-op），动态读取插件当前值。
@MainActor
final class TurnFinishedNotificationHook {
    private let isActive: @MainActor () -> Bool
    private let notifier: @MainActor (String, String, UUID) -> Void

    init(
        isActive: @escaping @MainActor () -> Bool,
        notifier: @escaping @MainActor (String, String, UUID) -> Void
    ) {
        self.isActive = isActive
        self.notifier = notifier
    }

    /// 处理回合结束事件；插件未激活时不发送通知。
    func apply(to context: TurnLifecycleContext) {
        guard isActive() else { return }
        let (title, body) = Self.presentation(for: context.endReason?.rawValue ?? "completed")
        notifier(title, body, context.conversationID)
    }

    // MARK: - Presentation

    /// 按结束原因生成通知标题与正文（纯函数，可测试）。
    nonisolated static func presentation(for reason: String) -> (title: String, body: String) {
        switch reason {
        case "completed":
            return ("任务完成", "Agent 回合已结束")
        case "failed":
            return ("任务失败", "Agent 回合执行失败")
        case "cancelled":
            return ("任务已取消", "Agent 回合已取消")
        default:
            return ("回合结束", "Agent 回合已结束")
        }
    }
}
