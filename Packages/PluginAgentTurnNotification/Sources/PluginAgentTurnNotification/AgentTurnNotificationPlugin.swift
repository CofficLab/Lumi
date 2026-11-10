import Foundation
import KernelCore
import ProviderAgentLoop
import ProviderConversation
import ProviderLifecycleHooks
import UserNotifications
import LumiLoggingKit
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
    ///
    /// - Note: 可写是为了让测试能显式声明环境。`swift test` 的 runner 没有
    ///   bundle identifier，按真实环境判定为 false，测试就会在 `onBoot` 的
    ///   环境探测处被短路，断言覆盖不到真正的 hook 注册链路。
    public static var isNotificationDeliveryAvailable: Bool {
        get { isNotificationDeliveryAvailableOverride ?? (Bundle.main.bundleIdentifier != nil) }
        set { isNotificationDeliveryAvailableOverride = newValue }
    }

    /// `isNotificationDeliveryAvailable` 的测试注入值；`nil` 表示按真实环境判定。
    nonisolated(unsafe) static var isNotificationDeliveryAvailableOverride: Bool?
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
    /// 点击通知后恢复来源会话的 delegate。
    private var tapHandler: TurnNotificationTapHandler?
    /// 通知发送器（测试可注入 no-op）。
    ///
    /// 无 bundle 的进程（命令行工具、headless agent 等）必须跳过：
    /// `UNUserNotificationCenter.current()` 在 `mainBundle.bundleURL` 不含
    /// bundle 时会抛 `NSInternalInconsistencyException`，直接终止进程。
    public var notifier: @MainActor (String, String, UUID) -> Void = { title, body, conversationID in
        guard AgentTurnNotificationPlugin.isNotificationDeliveryAvailable else { return }
        UNUserNotificationCenter.current().add(
            AgentTurnNotificationPlugin.notificationRequest(
                title: title,
                body: body,
                conversationID: conversationID
            )
        )
    }

    /// 点击通知后把应用带向前台的实现；测试可注入 no-op。
    var activateApplication: @MainActor () -> Void = {
        TurnNotificationTapHandler.activateHostApplication()
    }
    /// 安装/移除通知中心 delegate；测试可注入以避免无 bundle 环境访问系统 API。
    var installTapHandler: @MainActor (TurnNotificationTapHandler) -> Void = { handler in
        UNUserNotificationCenter.current().delegate = handler
    }
    var uninstallTapHandler: @MainActor (TurnNotificationTapHandler) -> Void = { handler in
        let center = UNUserNotificationCenter.current()
        if center.delegate === handler {
            center.delegate = nil
        }
    }

    /// 发送侧构造的通知请求；`userInfo` 必须携带来源会话 ID 供点击路由使用。
    static func notificationRequest(
        title: String,
        body: String,
        conversationID: UUID
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = [
            TurnNotificationTapHandler.conversationIDKey: conversationID.uuidString,
        ]
        return UNNotificationRequest(
            identifier: "turn-finished-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
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

        let conversations = kernel.resolveProvider((any ConversationManaging).self)
        let tapHandler = TurnNotificationTapHandler(
            activateApplication: activateApplication,
            selectConversation: { conversationID in
                conversations?.selectConversation(id: conversationID)
            }
        )
        self.tapHandler = tapHandler
        installTapHandler(tapHandler)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        if let tapHandler {
            uninstallTapHandler(tapHandler)
            self.tapHandler = nil
        }
        isActive = false
        turnFinishedHook = nil
    }

    // MARK: - Private

    // 通知授权由宿主 App 在启动时请求；插件只负责订阅并发送。
}
