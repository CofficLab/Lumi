import Foundation
import KernelCore
import ProviderAgentLoop
import ProviderConversation
import UserNotifications

/// 回合通知插件：回合结束时发系统通知。
///
/// 复刻自旧版 `Plugins/AgentTurnNotificationPlugin`，新版改为系统通知：
/// - 订阅事件总线的 `lumiTurnFinished`（回合结束，含 completed / failed / cancelled）；
/// - 用 `UNUserNotificationCenter` 发应用通知。
///
/// 通知发送经 `notifier` 闭包注入（默认走 `UNUserNotificationCenter`），
/// 便于测试注入 no-op 避免系统 API。
@MainActor
public final class AgentTurnNotificationPlugin: SuperPlugin {
    /// 保持旧版插件 ID。
    public let id = "com.coffic.lumi.plugin.turn-notification"
    public let order = 99
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.turn-notification",
        name: "Agent Turn Notification",
        description: "",
        category: .general,
        stage: .stable,
        policy: .alwaysOn
    )

    private var observers: [NSObjectProtocol] = []
    /// 通知发送器（测试可注入 no-op）。
    public var notifier: @MainActor (String, String, UUID) -> Void = { title, body, _ in
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "turn-finished-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    public init() {}


    public func onBoot(kernel: KernelCoreContainer) throws {
        // 注意：不在插件启动时请求通知授权（测试/无 bundle 环境会崩溃）。
        // 通知授权由宿主 App 在启动时请求；插件只负责订阅并发送。

        let finishedObserver = NotificationCenter.default.addObserver(
            forName: .lumiTurnFinished,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let conversationID = notification.userInfo?["conversationID"] as? UUID else { return }
            let reason = notification.userInfo?["reason"] as? String ?? "completed"
            let (title, body) = Self.presentation(for: reason)
            self.notifier(title, body, conversationID)
        }
        observers.append(finishedObserver)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
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

    // MARK: - Private

    // 通知授权由宿主 App 在启动时请求；插件只负责订阅并发送。
}
