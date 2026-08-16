import Foundation
import KernelCore
import ProviderSettingView
import Testing

@testable import PluginPluginManager

@MainActor
struct PluginPluginManagerTests {

    /// 插件 id 与旧版 PluginManagerPlugin 完全一致（保证状态存储兼容），
    /// 顺序与策略对齐旧版（order 90 / alwaysOn → required）。
    @Test
    func pluginMetadataMatchesLegacy() {
        let plugin = PluginPluginManager()
        #expect(plugin.id == "com.coffic.lumi.plugin.plugin-manager")
        #expect(plugin.order == 90)
        #expect(plugin.metadata.policy == .required)
        #expect(plugin.metadata.category == .system)
        #expect(plugin.metadata.stage == .stable)
    }

    /// onBoot 注册「插件管理」设置入口；onShutdown 撤回入口。
    @Test
    func onBootRegistersSettingEntryAndShutdownRemoves() throws {
        let settings = DefaultSettingViewProviding()
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any SettingViewProviding).self, settings)

        let plugin = PluginPluginManager()
        try plugin.onBoot(kernel: kernel)
        #expect(settings.entries.contains { $0.id == "plugin-manager" })

        try plugin.onShutdown(kernel: kernel)
        #expect(!settings.entries.contains { $0.id == "plugin-manager" })
    }

    /// 设置入口的标题 / 图标 / 顺序与旧版 SettingsTabItem 对齐。
    @Test
    func entryUsesLegacyPresentation() throws {
        let settings = DefaultSettingViewProviding()
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any SettingViewProviding).self, settings)

        let plugin = PluginPluginManager()
        try plugin.onBoot(kernel: kernel)

        let entry = settings.entries.first { $0.id == "plugin-manager" }
        #expect(entry?.title == "插件管理")
        #expect(entry?.systemImage == "puzzlepiece.extension")
        #expect(entry?.order == 3)
    }

    /// 设置视图未注册时优雅降级：onBoot 不抛错、不贡献入口。
    @Test
    func onBootDegradesGracefullyWithoutSettingsProvider() throws {
        let kernel = KernelCoreContainer()
        let plugin = PluginPluginManager()
        try plugin.onBoot(kernel: kernel) // 不应抛错
        #expect(kernel.resolveProvider((any SettingViewProviding).self) == nil)
    }
}
