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

    /// 当前进程是否可以使用 `UNUserNotificationCenter`。
    ///
    /// 判据是存在 bundle identifier：未签名/无 bundle 的可执行文件
    /// （如 `lumi-acp` 独立调试产物）取不到它，此时系统框架会直接抛异常。
    public static var isNotificationDeliveryAvailable: Bool {
        Bundle.main.bundleIdentifier != nil
    }
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
    ///
    /// 无 bundle 的进程（命令行工具、headless agent 等）必须跳过：
    /// `UNUserNotificationCenter.current()` 在 `mainBundle.bundleURL` 不含
    /// bundle 时会抛 `NSInternalInconsistencyException`，直接终止进程。
    public var notifier: @MainActor (String, String, UUID) -> Void = { title, body, _ in
        guard AgentTurnNotificationPlugin.isNotificationDeliveryAvailable else { return }
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
        // 发送侧同样需要保护，见 `isNotificationDeliveryAvailable`。

        guard AgentTurnNotificationPlugin.isNotificationDeliveryAvailable else {
            Self.logger.info(
                "\(Self.t)当前进程无 bundle，跳过回合结束通知（headless/CLI 环境）"
            )
            return
        }

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
