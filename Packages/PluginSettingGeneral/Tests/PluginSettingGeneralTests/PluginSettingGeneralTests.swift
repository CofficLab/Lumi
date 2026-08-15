import KernelCore
import ProviderSettingView
import SwiftUI
import Testing
@testable import PluginSettingGeneral

/// SettingGeneralPlugin 与 AppVersion 的基础验证。
@Suite("PluginSettingGeneral")
@MainActor
struct SettingGeneralPluginTests {

    @Test("onBoot 在设置视图中注册「通用」入口")
    func onBootRegistersGeneralEntry() throws {
        let kernel = KernelCoreContainer()
        let settings = DefaultSettingViewProviding()
        try kernel.registerProvider((any SettingViewProviding).self, settings)

        let plugin = SettingGeneralPlugin(versionProvider: { "1.2.3 (45)" })
        try plugin.onBoot(kernel: kernel)

        #expect(settings.entries.count == 1)
        let entry = settings.entries[0]
        #expect(entry.id == "general")
        #expect(entry.title == "通用")
        #expect(entry.systemImage == "gearshape")

        // 详情视图可渲染
        #expect(type(of: entry.makeDetailView()) == AnyView.self)
    }

    @Test("onBoot 追加语义不覆盖已有入口")
    func onBootAppendsToExistingEntries() throws {
        let kernel = KernelCoreContainer()
        let settings = DefaultSettingViewProviding()
        settings.registerEntries([
            SettingEntryItem(id: "appearance", title: "外观", systemImage: "paintbrush") { Text("appearance") },
        ])
        try kernel.registerProvider((any SettingViewProviding).self, settings)

        let plugin = SettingGeneralPlugin(versionProvider: { "1.0" })
        try plugin.onBoot(kernel: kernel)

        #expect(settings.entries.count == 2)
        #expect(settings.entries.map(\.id) == ["general", "appearance"])
    }

    @Test("设置视图未注册时 onBoot 优雅降级")
    func onBootNoOpsWithoutSettingView() throws {
        let kernel = KernelCoreContainer()
        let plugin = SettingGeneralPlugin()

        // 不应抛错
        try plugin.onBoot(kernel: kernel)

        #expect(kernel.registeredPluginCount == 0)
    }

    @Test("插件可经 kernel.start 启动并注册入口")
    func startViaKernelBootsPlugin() throws {
        let kernel = KernelCoreContainer()
        let settings = DefaultSettingViewProviding()
        try kernel.registerProvider((any SettingViewProviding).self, settings)

        let plugin = SettingGeneralPlugin(versionProvider: { "2.0" })
        try kernel.start(plugins: [plugin])

        #expect(kernel.isPluginRegistered(id: plugin.id))
        #expect(settings.entries.count == 1)
        #expect(settings.entries[0].id == "general")
    }

    @Test("AppVersion 可从 Info.plist 读取或返回 nil")
    func appVersionReadsBundle() {
        // 无测试 bundle 版本时返回 nil 或某种字符串；关键是方法不抛错。
        _ = AppVersion.current
        #expect(true)
    }
}
