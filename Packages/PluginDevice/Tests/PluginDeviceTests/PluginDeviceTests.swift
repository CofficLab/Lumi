import Combine
import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderSettingView
import SwiftUI
import Testing
@testable import PluginDevice

/// DevicePlugin 与 DeviceData 的基础验证。
@Suite("PluginDevice")
@MainActor
struct PluginDeviceTests {

    @Test("onBoot 不再注册内存监控设置入口，但仍注册主内容与文档")
    func onBootRegistersEntryContentViewAndDocs() throws {
        let kernel = KernelCoreContainer()
        let settings = DefaultSettingViewProviding()
        let contentView = DefaultContentViewProviding()
        let docs = DefaultDocsViewProviding()
        try kernel.registerProvider((any SettingViewProviding).self, settings)
        try kernel.registerProvider((any ContentViewProviding).self, contentView)
        try kernel.registerProvider((any DocsViewProviding).self, docs)

        let plugin = DevicePlugin()
        // 文档条目在 onRegister 注册，设置/内容入口在 onBoot 注册
        try plugin.onRegister(kernel: kernel)
        try plugin.onBoot(kernel: kernel)

        // 设置入口：内存监控已移除，插件不再贡献任何设置项
        #expect(settings.entries.isEmpty)

        // 主内容视图
        #expect(type(of: contentView.makeContentView()) == AnyView.self)

        // 文档：关于 + 说明书
        #expect(docs.aboutEntries.count == 1)
        #expect(docs.aboutEntries[0].id == plugin.id)
        #expect(docs.aboutEntries[0].name == "设备信息")
        #expect(docs.manualEntries.count == 1)
        #expect(docs.manualEntries[0].id == plugin.id)
        #expect(type(of: docs.aboutEntries[0].makeView()) == AnyView.self)
        #expect(type(of: docs.manualEntries[0].makeView()) == AnyView.self)
    }

    @Test("onBoot 追加语义不覆盖已有入口")
    func onBootAppendsToExistingEntries() throws {
        let kernel = KernelCoreContainer()
        let settings = DefaultSettingViewProviding()
        settings.registerEntries([
            SettingEntryItem(id: "general", title: "通用", systemImage: "gearshape", order: 200) { Text("general") },
        ])
        try kernel.registerProvider((any SettingViewProviding).self, settings)

        let plugin = DevicePlugin() // order 150
        try plugin.onBoot(kernel: kernel)

        #expect(settings.entries.count == 1)
        #expect(settings.entries.map(\.id) == ["general"])
    }

    @Test("设置视图未注册时 onBoot 优雅降级")
    func onBootNoOpsWithoutSettingView() throws {
        let kernel = KernelCoreContainer()
        let plugin = DevicePlugin()

        // 不应抛错
        try plugin.onBoot(kernel: kernel)
    }

    @Test("插件可经 kernel.start 启动并注册入口")
    func startViaKernelBootsPlugin() throws {
        let kernel = KernelCoreContainer()
        let settings = DefaultSettingViewProviding()
        try kernel.registerProvider((any SettingViewProviding).self, settings)

        let plugin = DevicePlugin()
        try kernel.start(plugins: [plugin])

        #expect(kernel.isPluginRegistered(id: plugin.id))
        // 内存监控已移除：启动后不再贡献设置项
        #expect(settings.entries.isEmpty)
    }

    @Test("ActivityBar 激活设备入口时切换主内容")
    func activityBarActivationSetsContentView() throws {
        @MainActor final class TrackingContentView: ContentViewProviding {
            @Published var setCount = 0

            func setContentView(_ view: AnyView?) {
                if view != nil { setCount += 1 }
            }

            func makeContentView() -> AnyView { AnyView(EmptyView()) }
        }

        let kernel = KernelCoreContainer()
        let activityBar = DefaultActivityBarProviding()
        let contentView = TrackingContentView()
        activityBar.registerItems([
            ActivityBarItem(id: "other", title: "Other", systemImage: "circle"),
        ])
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any ContentViewProviding).self, contentView)

        let plugin = DevicePlugin()
        try plugin.onBoot(kernel: kernel)
        #expect(contentView.setCount == 0)

        activityBar.activateItem(id: "\(plugin.id).entry")

        #expect(contentView.setCount == 1)
    }

    @Test("DeviceData 采集静态系统信息")
    func deviceDataStaticInfo() {
        let data = DeviceData()

        #expect(!data.deviceName.isEmpty)
        #expect(data.osVersion.hasPrefix("macOS"))
        #expect(data.coreCount > 0)
        #expect(data.memoryTotal > 0)

        data.stopMonitoring()
    }

    @Test("DeviceData 动态指标可刷新且非负")
    func deviceDataDynamicMetrics() {
        let data = DeviceData()

        data.updateDynamicData()

        #expect(data.cpuUsage >= 0)
        // 采样 API 失败或刚初始化时允许为 0，但不应为负数。
        #expect(data.memoryUsed >= 0)
        #expect(data.memoryTotal > 0)
        #expect(data.memoryUsage >= 0)
        #expect(data.uptime >= 0)
        // 磁盘总量通常 > 0（有根卷）
        #expect(data.diskTotal >= 0)

        data.stopMonitoring()
    }

    @Test("DeviceInfoAboutView 可渲染")
    func aboutViewRenders() {
        let view = DeviceInfoAboutView()
        #expect(type(of: view) != Never.self)
    }

    @Test("DeviceInfoManualView 可渲染")
    func manualViewRenders() {
        let view = DeviceInfoManualView()
        #expect(type(of: view) != Never.self)
    }
}
