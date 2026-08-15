import KernelCore
import ProviderContentView
import ProviderSettingView
import SwiftUI
import Testing
@testable import PluginDevice

/// DevicePlugin 与 DeviceData 的基础验证。
@Suite("PluginDevice")
@MainActor
struct PluginDeviceTests {

    @Test("onBoot 注册设置入口并把设备信息设为主内容")
    func onBootRegistersEntryAndContentView() throws {
        let kernel = KernelCoreContainer()
        let settings = DefaultSettingViewProviding()
        let contentView = DefaultContentViewProviding()
        try kernel.registerProvider((any SettingViewProviding).self, settings)
        try kernel.registerProvider((any ContentViewProviding).self, contentView)

        let plugin = DevicePlugin()
        try plugin.onBoot(kernel: kernel)

        // 设置入口
        #expect(settings.entries.count == 1)
        let entry = settings.entries[0]
        #expect(entry.id == "device")
        #expect(entry.title == "设备信息")
        #expect(type(of: entry.makeDetailView()) == AnyView.self)

        // 主内容视图
        #expect(type(of: contentView.makeContentView()) == AnyView.self)
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

        #expect(settings.entries.count == 2)
        // 合并后按 order 升序：device(150) 在前，general(200) 在后
        #expect(settings.entries.map(\.id) == ["device", "general"])
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
        #expect(settings.entries.count == 1)
        #expect(settings.entries[0].id == "device")
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
        #expect(data.memoryUsed > 0)
        #expect(data.memoryTotal > 0)
        #expect(data.memoryUsage >= 0)
        #expect(data.uptime >= 0)
        // 磁盘总量通常 > 0（有根卷）
        #expect(data.diskTotal >= 0)

        data.stopMonitoring()
    }
}
