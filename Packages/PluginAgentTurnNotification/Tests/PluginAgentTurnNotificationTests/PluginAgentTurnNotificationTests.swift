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

    @Test("presentation 按原因生成标题")
    func presentationTitles() {
        #expect(TurnFinishedNotificationHook.presentation(for: "completed").title == "任务完成")
        #expect(TurnFinishedNotificationHook.presentation(for: "failed").title == "任务失败")
        #expect(TurnFinishedNotificationHook.presentation(for: "cancelled").title == "任务已取消")
        #expect(TurnFinishedNotificationHook.presentation(for: "unknown").title == "回合结束")
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
        #expect(notified == ["任务完成"])

        try plugin.onShutdown(kernel: kernel)
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
