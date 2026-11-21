import Foundation
import Testing
import KernelCore
import ProviderConversation
import ProviderLifecycleHooks

@testable import PluginAgentTurnNotification

@Suite("AgentTurnNotificationPlugin", .serialized)
@MainActor
struct AgentTurnNotificationPluginTests {
    @Test("插件 onBoot/onShutdown 不抛错")
    func lifecycle() throws {
        let kernel = KernelCoreContainer()
        let plugin = AgentTurnNotificationPlugin()
        plugin.notifier = { _, _, _ in } // no-op，避免系统 API
        try plugin.onBoot(kernel: kernel)
        try plugin.onShutdown(kernel: kernel)
    }

    @Test("presentation 按原因经本地化解析生成标题与正文")
    func presentationTitles() {
        let resolve: (String) -> String = { "key:\($0)" }

        let completed = TurnFinishedNotificationHook.presentation(for: "completed", resolve: resolve)
        #expect(completed.title == "key:Task Completed")
        #expect(completed.body == "key:Agent turn finished")

        let failed = TurnFinishedNotificationHook.presentation(for: "failed", resolve: resolve)
        #expect(failed.title == "key:Task Failed")
        #expect(failed.body == "key:Agent turn failed")

        let cancelled = TurnFinishedNotificationHook.presentation(for: "cancelled", resolve: resolve)
        #expect(cancelled.title == "key:Task Cancelled")
        #expect(cancelled.body == "key:Agent turn cancelled")

        let unknown = TurnFinishedNotificationHook.presentation(for: "unknown", resolve: resolve)
        #expect(unknown.title == "key:Turn Finished")
        #expect(unknown.body == "key:Agent turn finished")
    }

    @Test("通知标题与正文在五种规范语言下都有译文（回归 #898）")
    func presentationLabelsHaveTranslationsInCompiledBundle() throws {
        let expected: [String: [String: String]] = [
            "Task Completed": [
                "en": "Task Completed",
                "zh-Hans": "任务完成",
                "zh-Hant": "任務完成",
                "zh-HK": "任務完成",
                "zh-TW": "任務完成",
            ],
            "Agent turn finished": [
                "en": "Agent turn finished",
                "zh-Hans": "Agent 回合已结束",
                "zh-Hant": "Agent 回合已結束",
                "zh-HK": "Agent 回合已結束",
                "zh-TW": "Agent 回合已結束",
            ],
            "Task Failed": [
                "en": "Task Failed",
                "zh-Hans": "任务失败",
                "zh-Hant": "任務失敗",
                "zh-HK": "任務失敗",
                "zh-TW": "任務失敗",
            ],
            "Agent turn failed": [
                "en": "Agent turn failed",
                "zh-Hans": "Agent 回合执行失败",
                "zh-Hant": "Agent 回合執行失敗",
                "zh-HK": "Agent 回合執行失敗",
                "zh-TW": "Agent 回合執行失敗",
            ],
            "Task Cancelled": [
                "en": "Task Cancelled",
                "zh-Hans": "任务已取消",
                "zh-Hant": "任務已取消",
                "zh-HK": "任務已取消",
                "zh-TW": "任務已取消",
            ],
            "Agent turn cancelled": [
                "en": "Agent turn cancelled",
                "zh-Hans": "Agent 回合已取消",
                "zh-Hant": "Agent 回合已取消",
                "zh-HK": "Agent 回合已取消",
                "zh-TW": "Agent 回合已取消",
            ],
            "Turn Finished": [
                "en": "Turn Finished",
                "zh-Hans": "回合结束",
                "zh-Hant": "回合結束",
                "zh-HK": "回合結束",
                "zh-TW": "回合結束",
            ],
        ]

        for (key, translations) in expected {
            for (language, translation) in translations {
                let table = try Self.compiledStrings(language: language)
                #expect(
                    table[key] == translation,
                    "\(language) 下 \(key) 译文缺失或不符，通知会回退成其它语言"
                )
            }
        }
    }

    private static func compiledStrings(language: String) throws -> [String: String] {
        let bundle = pluginLocalization.bundle
        let lprojPath = try #require(bundle.path(forResource: language, ofType: "lproj"))
        let stringsPath = (lprojPath as NSString).appendingPathComponent("Localizable.strings")
        return try #require(NSDictionary(contentsOfFile: stringsPath) as? [String: String])
    }

    @Test("V2 turn-finished hook 触发 notifier")
    func finishedTriggersNotifier() async throws {
        // 测试进程是 xctest runner，没有 bundle identifier，
        // `isNotificationDeliveryAvailable` 因此为 false，`onBoot` 会跳过 hook 注册。
        // 这里显式置 true，让断言覆盖的是「hook 注册与触发」这条真实链路，
        // 而不是被环境探测提前短路后的空路径。
        let originalAvailability = AgentTurnNotificationPlugin.isNotificationDeliveryAvailable
        AgentTurnNotificationPlugin.isNotificationDeliveryAvailable = true
        defer { AgentTurnNotificationPlugin.isNotificationDeliveryAvailable = originalAvailability }

        let kernel = KernelCoreContainer()
        let hooks = DefaultLifecycleHooksProvider()
        try kernel.registerProvider((any LifecycleHooksProviding).self, hooks)
        let plugin = AgentTurnNotificationPlugin()
        var notified: [String] = []
        plugin.notifier = { title, _, _ in notified.append(title) }
        plugin.installTapHandler = { _ in }
        plugin.uninstallTapHandler = { _ in }
        try plugin.onBoot(kernel: kernel)

        let conversationID = UUID()
        await hooks.notifyTurnFinished(
            TurnLifecycleContext(
                conversationID: conversationID,
                turnID: UUID(),
                endReason: .completed
            )
        )
        #expect(notified == [pluginLocalization.string("Task Completed")])

        try plugin.onShutdown(kernel: kernel)
    }

    /// 回归 #787：挂起是非终态，不得发「回合结束」通知；
    /// 同一回合恢复后真正完成时，只发那一次终态通知。
    @Test("挂起不发通知，恢复后的真实终态只通知一次")
    func suspensionDoesNotNotify() async throws {
        let originalAvailability = AgentTurnNotificationPlugin.isNotificationDeliveryAvailable
        AgentTurnNotificationPlugin.isNotificationDeliveryAvailable = true
        defer { AgentTurnNotificationPlugin.isNotificationDeliveryAvailable = originalAvailability }

        let kernel = KernelCoreContainer()
        let hooks = DefaultLifecycleHooksProvider()
        try kernel.registerProvider((any LifecycleHooksProviding).self, hooks)
        let plugin = AgentTurnNotificationPlugin()
        var notified: [String] = []
        plugin.notifier = { title, _, _ in notified.append(title) }
        plugin.installTapHandler = { _ in }
        plugin.uninstallTapHandler = { _ in }
        try plugin.onBoot(kernel: kernel)

        let conversationID = UUID()
        let turnID = UUID()
        // ask_user / 工具授权挂起：回合还活着，不能宣称结束。
        await hooks.notifyTurnFinished(
            TurnLifecycleContext(
                conversationID: conversationID,
                turnID: turnID,
                endReason: .suspended
            )
        )
        #expect(notified.isEmpty, "挂起不是终态，不应发送回合结束通知")

        // 用户回答后同一回合真正完成。
        await hooks.notifyTurnFinished(
            TurnLifecycleContext(
                conversationID: conversationID,
                turnID: turnID,
                endReason: .completed
            )
        )
        #expect(notified == [pluginLocalization.string("Task Completed")])

        try plugin.onShutdown(kernel: kernel)
    }

    @Test("钩子层直接跳过 suspended，其余终态照常通知")
    func hookSkipsSuspendedReason() {
        var notified: [(String, String)] = []
        let hook = TurnFinishedNotificationHook(
            isActive: { true },
            notifier: { title, body, _ in notified.append((title, body)) }
        )
        let conversationID = UUID()
        let turnID = UUID()

        hook.apply(to: TurnLifecycleContext(
            conversationID: conversationID, turnID: turnID, endReason: .suspended
        ))
        #expect(notified.isEmpty)

        hook.apply(to: TurnLifecycleContext(
            conversationID: conversationID, turnID: turnID, endReason: .cancelled
        ))
        #expect(notified.count == 1)
        #expect(notified[0].0 == pluginLocalization.string("Task Cancelled"))
    }

    @Test("通知请求携带来源会话 ID")
    func notificationRequestCarriesConversationID() {
        let conversationID = UUID()
        let request = AgentTurnNotificationPlugin.notificationRequest(
            title: "任务完成",
            body: "Agent 回合已结束",
            conversationID: conversationID
        )

        let storedID = request.content.userInfo[TurnNotificationTapHandler.conversationIDKey] as? String
        #expect(storedID == conversationID.uuidString)
        #expect(request.content.title == "任务完成")
        #expect(request.content.body == "Agent 回合已结束")
        #expect(request.content.sound != nil)
    }

    @Test("前台送达展示横幅并播放声音（回归 #457）")
    func foregroundPresentationShowsBannerAndSound() {
        let options = TurnNotificationTapHandler.foregroundPresentationOptions()
        #expect(options.contains(.banner))
        #expect(options.contains(.sound))
    }

    /// 轮询等待门控流里 fire-and-forget 的 Task 完成。
    private func waitFor(
        _ condition: () -> Bool,
        timeout: TimeInterval = 2
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return condition()
    }

    /// 回归 #456：首次发送先请求系统授权；被拒不投递，同意才投递，
    /// 且授权确认后不再重复请求。
    @Test("首次发送先请求授权，被拒不投递，同意后投递一次（回归 #456）")
    func firstSendRequestsAuthorizationAndGatesDelivery() async throws {
        let originalAvailability = AgentTurnNotificationPlugin.isNotificationDeliveryAvailable
        AgentTurnNotificationPlugin.isNotificationDeliveryAvailable = true
        defer { AgentTurnNotificationPlugin.isNotificationDeliveryAvailable = originalAvailability }

        let plugin = AgentTurnNotificationPlugin()
        var requestCount = 0
        var authorizationGranted = false
        plugin.requestAuthorization = {
            requestCount += 1
            return authorizationGranted
        }
        var delivered: [String] = []
        plugin.deliverNotification = { title, _, _ in delivered.append(title) }

        // 授权被拒：请求一次，不投递。
        plugin.notifier("任务完成", "body", UUID())
        #expect(await waitFor { requestCount == 1 }, "首次发送应触发授权请求")
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(requestCount == 1)
        #expect(delivered.isEmpty, "授权被拒时不应投递通知")

        // 用户允许后：再次发送触发第二次请求并投递。
        authorizationGranted = true
        plugin.notifier("任务完成", "body", UUID())
        #expect(await waitFor { !delivered.isEmpty }, "授权同意后应投递通知")
        #expect(delivered == ["任务完成"])
        #expect(requestCount == 2)

        // 已确认授权：后续发送直接投递，不再重复请求。
        plugin.notifier("任务失败", "body", UUID())
        #expect(await waitFor { delivered.count == 2 }, "已授权的发送应直接投递")
        #expect(delivered == ["任务完成", "任务失败"])
        #expect(requestCount == 2, "授权确认后不应重复请求")
    }

    @Test("点击通知激活应用并选中来源会话")
    func tapSelectsOriginatingConversation() throws {
        let originalAvailability = AgentTurnNotificationPlugin.isNotificationDeliveryAvailable
        AgentTurnNotificationPlugin.isNotificationDeliveryAvailable = true
        defer { AgentTurnNotificationPlugin.isNotificationDeliveryAvailable = originalAvailability }

        let kernel = KernelCoreContainer()
        let conversations = DefaultConversationManager(
            dataDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("NotificationTap-\(UUID().uuidString)", isDirectory: true)
        )
        try kernel.registerProvider((any ConversationManaging).self, conversations)

        let plugin = AgentTurnNotificationPlugin()
        plugin.notifier = { _, _, _ in }
        var installedHandler: TurnNotificationTapHandler?
        var didUninstall = false
        plugin.installTapHandler = { installedHandler = $0 }
        plugin.uninstallTapHandler = { _ in didUninstall = true }
        var didActivate = false
        plugin.activateApplication = { didActivate = true }
        try plugin.onBoot(kernel: kernel)

        let handler = try #require(installedHandler)
        let conversationID = UUID()
        let handled = handler.handleTap(userInfo: [
            TurnNotificationTapHandler.conversationIDKey: conversationID.uuidString,
        ])

        #expect(handled)
        #expect(didActivate)
        #expect(conversations.selectedConversationID == conversationID)

        try plugin.onShutdown(kernel: kernel)
        #expect(didUninstall)
    }

    @Test("缺少或非法会话 ID 的通知点击不改变选中会话")
    func tapIgnoresInvalidConversationID() {
        var activations = 0
        var selectedID: UUID?
        let handler = TurnNotificationTapHandler(
            activateApplication: { activations += 1 },
            selectConversation: { selectedID = $0 }
        )

        #expect(handler.handleTap(userInfo: [:]) == false)
        #expect(handler.handleTap(userInfo: [
            TurnNotificationTapHandler.conversationIDKey: "not-a-uuid",
        ]) == false)
        #expect(activations == 0)
        #expect(selectedID == nil)
    }
}
