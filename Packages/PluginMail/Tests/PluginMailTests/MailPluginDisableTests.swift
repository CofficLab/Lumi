import Foundation
import KernelCore
import ProviderActivityBar
import ProviderSettingView
import ProviderToolManager
import KitTestSupport
import Testing
@testable import PluginMail

/// 运行时禁用必须撤回全部 Provider 侧贡献（issue #452）。
///
/// 内核的运行时禁用只调用 `onDisable`（Browser #451 同类问题）：不会调用
/// `onShutdown`，也不会代撤直接注册在各 Provider 上的贡献。旧实现没有
/// `onDisable`，禁用后 5 个 Mail Agent 工具仍可执行、设置入口与
/// ActivityBar 入口仍在、账户会话不断开。
@Suite("MailPlugin 运行时禁用", .serialized)
@MainActor
struct MailPluginDisableTests {

    private static let expectedToolNames = [
        MailListAccountsTool.toolName,
        MailListMessagesTool.toolName,
        MailReadMessageTool.toolName,
        MailSearchMessagesTool.toolName,
        MailSendMessageTool.toolName,
    ]

    /// 注册 ToolManager / SettingView / ActivityBar 三个默认 Provider 的内核。
    private func makeKernel() -> (KernelCoreContainer, DefaultToolManagerProviding, DefaultSettingViewProviding, DefaultActivityBarProviding) {
        let kernel = KernelCoreContainer()
        let toolManager = DefaultToolManagerProviding()
        let settingView = DefaultSettingViewProviding()
        let activityBar = DefaultActivityBarProviding()
        try? kernel.registerProvider((any ToolManagerProviding).self, toolManager)
        try? kernel.registerProvider((any SettingViewProviding).self, settingView)
        try? kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        return (kernel, toolManager, settingView, activityBar)
    }

    @Test("onDisable 注销全部 Mail 工具与两个入口")
    func disableWithdrawsToolsAndEntries() async throws {
        let root = try TemporaryDirectory.make("mail-disable-withdraw")
        defer { root.remove() }
        MailPluginRuntime.injectedFallbackDataDirectory = root.url
        defer { MailPluginRuntime.injectedFallbackDataDirectory = nil }

        let (kernel, toolManager, settingView, activityBar) = makeKernel()
        let plugin = MailPlugin()
        try plugin.onBoot(kernel: kernel)
        try await plugin.onDisable(kernel: kernel)

        for name in Self.expectedToolNames {
            #expect(toolManager.tool(named: name) == nil, "工具 \(name) 在禁用后仍注册")
        }
        #expect(settingView.entries.isEmpty, "设置入口在禁用后仍存在")
        #expect(!activityBar.items.contains(where: { $0.id == "com.coffic.lumi.plugin.mail.entry" }), "ActivityBar 入口在禁用后仍存在")
    }

    @Test("onDisable 后 onEnable 重新注册全部工具与入口")
    func reEnableRestoresToolsAndEntries() async throws {
        let root = try TemporaryDirectory.make("mail-disable-reenable")
        defer { root.remove() }
        MailPluginRuntime.injectedFallbackDataDirectory = root.url
        defer { MailPluginRuntime.injectedFallbackDataDirectory = nil }

        let (kernel, toolManager, settingView, activityBar) = makeKernel()
        let plugin = MailPlugin()
        try plugin.onBoot(kernel: kernel)
        try await plugin.onDisable(kernel: kernel)
        // 前置确认：禁用确实撤回了贡献，否则重装断言无法区分「恢复了」与「从未撤回」。
        for name in Self.expectedToolNames {
            #expect(toolManager.tool(named: name) == nil, "前置失败：工具 \(name) 在禁用后仍注册")
        }
        try await plugin.onEnable(kernel: kernel)

        for name in Self.expectedToolNames {
            #expect(toolManager.tool(named: name) != nil, "工具 \(name) 重新启用后未注册")
        }
        #expect(settingView.entries.contains(where: { $0.id == "com.coffic.lumi.plugin.mail.settings" }), "重新启用后设置入口缺失")
        #expect(activityBar.items.contains(where: { $0.id == "com.coffic.lumi.plugin.mail.entry" }), "重新启用后 ActivityBar 入口缺失")
    }
}
