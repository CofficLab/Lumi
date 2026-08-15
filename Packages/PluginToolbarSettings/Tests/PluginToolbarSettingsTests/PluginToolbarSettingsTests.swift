import KernelCore
import ProviderToolbar
import SwiftUI
import Testing
@testable import PluginToolbarSettings

/// SettingsToolbarPlugin 的基础验证。
@Suite("PluginToolbarSettings")
@MainActor
struct PluginToolbarSettingsTests {

    @Test("onBoot 在工具栏右侧注册设置按钮")
    func onBootRegistersSettingsButton() throws {
        let kernel = KernelCoreContainer()
        let toolbar = DefaultToolbarProviding()
        try kernel.registerProvider((any ToolbarProviding).self, toolbar)

        let plugin = SettingsToolbarPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(toolbar.toolbarItems.count == 1)
        let item = toolbar.toolbarItems[0]
        #expect(item.id == "settings")
        #expect(item.title == "设置")
        #expect(item.placement == .trailing)

        // 按钮视图可渲染
        #expect(type(of: item.makeView()) == AnyView.self)
    }

    @Test("onBoot 追加语义不覆盖已有项")
    func onBootAppendsToExistingItems() throws {
        let kernel = KernelCoreContainer()
        let toolbar = DefaultToolbarProviding()
        toolbar.registerToolbarItems([
            ToolbarItem(id: "run", title: "Run", placement: .leading) { Text("run") },
        ])
        try kernel.registerProvider((any ToolbarProviding).self, toolbar)

        let plugin = SettingsToolbarPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(toolbar.toolbarItems.count == 2)
        #expect(toolbar.toolbarItems.contains(where: { $0.id == "settings" }))
    }

    @Test("工具栏未注册时 onBoot 优雅降级")
    func onBootNoOpsWithoutToolbar() throws {
        let kernel = KernelCoreContainer()
        let plugin = SettingsToolbarPlugin()

        // 不应抛错
        try plugin.onBoot(kernel: kernel)
    }

    @Test("插件可经 kernel.start 启动并注册按钮")
    func startViaKernelBootsPlugin() throws {
        let kernel = KernelCoreContainer()
        let toolbar = DefaultToolbarProviding()
        try kernel.registerProvider((any ToolbarProviding).self, toolbar)

        let plugin = SettingsToolbarPlugin()
        try kernel.start(plugins: [plugin])

        #expect(kernel.isPluginRegistered(id: plugin.id))
        #expect(toolbar.toolbarItems.count == 1)
        #expect(toolbar.toolbarItems[0].id == "settings")
    }
}
