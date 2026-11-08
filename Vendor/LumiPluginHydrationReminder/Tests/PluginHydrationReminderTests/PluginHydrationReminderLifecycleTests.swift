import KernelCore
import ProviderDocsView
import ProviderSettingView
import ProviderMenuBar
import SwiftUI
import Testing
@testable import PluginHydrationReminder

/// 喝水提醒插件的核心契约是「onBoot 注册状态栏弹窗与设置入口、
/// onShutdown 按 id 撤回」。这里通过真实的 Provider 验证注册表行为，
/// 不触碰视图渲染。
///
/// 生命周期一律经由 `kernel.start(plugins:)` / `kernel.stop()` 触发，
/// 以保证 Kernel 的插件归属与真实运行一致。
@Suite("PluginHydrationReminder 生命周期")
@MainActor
struct PluginHydrationReminderLifecycleTests {
    private func makeKernel(
        withPopups: Bool = true,
        withSettings: Bool = true
    ) throws -> (
        kernel: KernelCoreContainer,
        popups: DefaultMenuBarProviding?,
        settings: DefaultSettingViewProviding?
    ) {
        let kernel = KernelCoreContainer()
        var popups: DefaultMenuBarProviding?
        var settings: DefaultSettingViewProviding?
        if withPopups {
            let provider = DefaultMenuBarProviding()
            try kernel.registerProvider(MenuBarProviding.self, provider)
            popups = provider
        }
        if withSettings {
            let provider = DefaultSettingViewProviding()
            try kernel.registerProvider((any SettingViewProviding).self, provider)
            settings = provider
        }
        return (kernel, popups, settings)
    }

    @Test("onBoot 注册状态栏弹窗")
    func onBootRegistersPopupView() throws {
        let (kernel, popups, _) = try makeKernel()

        try kernel.start(plugins: [PluginHydrationReminder()])

        #expect((popups?.popupItems ?? []).count == 1)
    }

    @Test("onBoot 注册设置入口")
    func onBootRegistersSettingEntry() throws {
        let (kernel, _, settings) = try makeKernel()

        try kernel.start(plugins: [PluginHydrationReminder()])

        let entries = settings?.entries ?? []
        #expect(entries.count == 1)
        #expect(entries.first?.id == PluginHydrationReminder.defaultPluginID)
        #expect(entries.first?.systemImage == "drop.fill")
    }

    @Test("onShutdown 撤回本插件贡献")
    func onShutdownRemovesContributions() throws {
        let (kernel, popups, settings) = try makeKernel()

        try kernel.start(plugins: [PluginHydrationReminder()])
        #expect((popups?.popupItems ?? []).count == 1)

        try kernel.stop()

        #expect((popups?.popupItems ?? []).isEmpty)
        #expect((settings?.entries ?? []).isEmpty)
    }

    @Test("禁用自动撤回，重新启用恢复弹窗")
    func disableAndEnableRestoresPopup() async throws {
        let (kernel, popups, _) = try makeKernel()
        let plugin = PluginHydrationReminder()
        try kernel.start(plugins: [plugin])

        try await kernel.disablePlugin(id: plugin.id)
        #expect((popups?.popupItems ?? []).isEmpty)

        try await kernel.enablePlugin(id: plugin.id)
        #expect(popups?.popupItems.map(\.id) == ["\(plugin.id).popup"])
    }

    @Test("onShutdown 不影响其它 owner 的弹窗")
    func onShutdownKeepsOtherOwnersPopupViews() throws {
        let (kernel, popups, _) = try makeKernel()
        popups?.addPopup(MenuBarContribution(
            id: "OtherPlugin.popup",
            title: "Other",
            ownerPluginID: "OtherPlugin"
        ) {
            Text("Other")
        })

        try kernel.start(plugins: [PluginHydrationReminder()])
        #expect((popups?.popupItems ?? []).count == 2)

        try kernel.stop()

        #expect((popups?.popupItems ?? []).count == 1)
    }

    @Test("缺少 provider 时优雅降级")
    func degradesWithoutProviders() throws {
        let (kernel, _, _) = try makeKernel(withPopups: false, withSettings: false)

        try kernel.start(plugins: [PluginHydrationReminder()])
        try kernel.stop()

        #expect(kernel.registeredPluginCount == 0)
    }

    @Test("插件元数据与 id 一致")
    func metadataMatchesID() {
        let plugin = PluginHydrationReminder()
        #expect(plugin.id == PluginHydrationReminder.defaultPluginID)
        #expect(plugin.metadata.id == plugin.id)
        #expect(plugin.order == 10)
        #expect(plugin.metadata.policy == .enabledByDefault)
    }

    @Test("宿主可注入品牌 id、顺序与启用策略")
    func hostCanInjectBrandIdentity() {
        let plugin = PluginHydrationReminder(
            id: "HydrationReminderPlugin",
            order: 11,
            policy: .disabled
        )

        #expect(plugin.id == "HydrationReminderPlugin")
        #expect(plugin.metadata.id == plugin.id)
        #expect(plugin.order == 11)
        #expect(plugin.metadata.policy == .disabled)
    }

    @Test("共享管理器初始未激活且无排期")
    func sharedManagerStartsInactive() {
        let shared = HydrationReminderManager.shared

        #expect(shared.isActive == false)
        #expect(shared.nextBreakTime == nil)
        #expect(shared.startTime == nil)
        #expect(shared.timeUntilNextBreak() == nil)
    }
}

/// 说明书条目由插件通过 `DocsViewProviding.addManual` 贡献，
/// 由设置页「通用 → 说明书」统一展示。
@Suite("PluginHydrationReminder 说明书贡献")
@MainActor
struct PluginHydrationReminderManualContributionTests {
    @Test("onBoot 贡献一条说明书条目")
    func onBootContributesManual() throws {
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = PluginHydrationReminder()
        try kernel.start(plugins: [plugin])

        #expect(docs.manualEntries.count == 1)
        #expect(docs.manualEntries.first?.id == plugin.id)
        #expect(docs.manualEntries.first?.name == plugin.metadata.name)
    }

    @Test("说明书视图可渲染")
    func manualViewRenders() throws {
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = PluginHydrationReminder()
        try kernel.start(plugins: [plugin])

        let entry = try #require(docs.manualEntries.first)
        _ = entry.makeView()
    }

    @Test("onShutdown 撤回本插件的说明书条目")
    func onShutdownRemovesManual() throws {
        let kernel = KernelCoreContainer()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = PluginHydrationReminder()
        try kernel.start(plugins: [plugin])
        #expect(docs.manualEntries.count == 1)

        try kernel.stop()

        #expect(docs.manualEntries.isEmpty)
    }
}
