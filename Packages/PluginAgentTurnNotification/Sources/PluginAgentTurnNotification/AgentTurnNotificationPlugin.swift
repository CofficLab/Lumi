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
    /// 通知发送入口（hook 调用）：首次发送先请求授权，授权通过才投递（#456）。
    ///
    /// 默认实现走完整门控流；测试注入替身即可绕过系统 API。
    public var notifier: @MainActor (String, String, UUID) -> Void {
        get {
            if let notifierOverride { return notifierOverride }
            return { [weak self] title, body, conversationID in
                guard let self else { return }
                if self.hasConfirmedAuthorization {
                    self.deliverNotification(title, body, conversationID)
                    return
                }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let granted = await self.requestAuthorization()
                    self.hasConfirmedAuthorization = granted
                    guard granted else {
                        Self.logger.info("\(Self.t)通知授权未通过，跳过回合结束通知")
                        return
                    }
                    self.deliverNotification(title, body, conversationID)
                }
            }
        }
        set { notifierOverride = newValue }
    }

    /// `notifier` 的注入值；`nil` 表示走默认门控流。
    private var notifierOverride: (@MainActor (String, String, UUID) -> Void)?

    /// 是否已确认过通知授权；确认后不再重复请求系统弹窗（#456）。
    private var hasConfirmedAuthorization = false

    /// 请求通知授权（alert + sound）；返回是否已授权。
    ///
    /// 系统 API 在已授权/已拒绝时会立即返回当前状态，不会重复弹窗。
    /// 测试可注入替身避免无 bundle 环境崩溃。
    var requestAuthorization: @MainActor () async -> Bool = {
        guard AgentTurnNotificationPlugin.isNotificationDeliveryAvailable else { return false }
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            AgentTurnNotificationPlugin.logger.error(
                "\(AgentTurnNotificationPlugin.t)请求通知授权失败：\(error)"
            )
            return false
        }
    }

    /// 授权通过后的实际投递；默认走 `UNUserNotificationCenter.add`。
    ///
    /// 无 bundle 的进程（命令行工具、headless agent 等）必须跳过：
    /// `UNUserNotificationCenter.current()` 在 `mainBundle.bundleURL` 不含
    /// bundle 时会抛 `NSInternalInconsistencyException`，直接终止进程。
    var deliverNotification: @MainActor (String, String, UUID) -> Void = { title, body, conversationID in
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
        // 通知授权不在插件启动时请求：首次实际发送时才请求（#456），
        // 避免启动即弹窗；无 bundle 进程仍直接跳过（见 isNotificationDeliveryAvailable）。

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
}
