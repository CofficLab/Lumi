import Foundation
import KernelCore
import ProviderAgentLoop
import ProviderConversation
import ProviderLifecycleHooks
import UserNotifications
import KitSuperLog
import os

/// 回合通知插件：回合结束时发系统通知。
///
/// 复刻自旧版 `Plugins/AgentTurnNotificationPlugin`，新版改为系统通知：
/// - 订阅事件总线的 `lumiTurnFinished`（回合结束，含 completed / failed / cancelled）；
/// - 用 `UNUserNotificationCenter` 发应用通知。
///
/// 通知发送经 `notifier` 闭包注入（默认走 `UNUserNotificationCenter`），
/// 便于测试注入 no-op 避免系统 API。
@MainActor
public final class AgentTurnNotificationPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.turn-notification", category: "AgentTurnNotification")
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

    private var isActive = false
    /// 回合结束通知钩子（见 `Hooks/TurnFinishedNotificationHook.swift`）。
    private var turnFinishedHook: TurnFinishedNotificationHook?
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

        isActive = true
        let hook = TurnFinishedNotificationHook(
            isActive: { [weak self] in self?.isActive ?? false },
            notifier: { [weak self] title, body, conversationID in
                self?.notifier(title, body, conversationID)
            }
        )
        turnFinishedHook = hook
        kernel.resolveProvider((any LifecycleHooksProviding).self)?
            .addTurnFinishedHook { [weak hook] context in
                hook?.apply(to: context)
            }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        isActive = false
        turnFinishedHook = nil
    }

    // MARK: - Private

    // 通知授权由宿主 App 在启动时请求；插件只负责订阅并发送。
}
