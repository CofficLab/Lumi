import Foundation
import Testing
import KernelCore
import ProviderConversation
import ProviderLifecycleHooks

@testable import PluginAgentTurnNotification

@Suite("AgentTurnNotificationPlugin")
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
        #expect(AgentTurnNotificationPlugin.presentation(for: "completed").title == "任务完成")
        #expect(AgentTurnNotificationPlugin.presentation(for: "failed").title == "任务失败")
        #expect(AgentTurnNotificationPlugin.presentation(for: "cancelled").title == "任务已取消")
        #expect(AgentTurnNotificationPlugin.presentation(for: "unknown").title == "回合结束")
    }

    @Test("V2 turn-finished hook 触发 notifier")
    func finishedTriggersNotifier() async throws {
        let kernel = KernelCoreContainer()
        let hooks = DefaultLifecycleHooksProvider()
        try kernel.registerProvider((any LifecycleHooksProviding).self, hooks)
        let plugin = AgentTurnNotificationPlugin()
        var notified: [String] = []
        plugin.notifier = { title, _, _ in notified.append(title) }
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
}
