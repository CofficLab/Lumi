import KernelCore
import PluginDeveloperMode
import ProviderDeveloperMode
import ProviderToolbar
import SwiftUI
import Testing

@Suite("PluginDeveloperMode")
@MainActor
struct DeveloperModePluginTests {
    @Test("registers the provider and a leading toolbar toggle")
    func bootRegistersProviderAndToolbarItem() throws {
        let kernel = KernelCoreContainer()
        let toolbar = DefaultToolbarProviding()
        try kernel.registerProvider((any ToolbarProviding).self, toolbar)
        // 生产环境由 FactoryLumi 在插件启动前注册；测试镜像该组装方式。
        try kernel.registerProvider((any DeveloperModeProviding).self, DefaultDeveloperModeProviding())

        let plugin = DeveloperModePlugin()
        try plugin.onBoot(kernel: kernel)

        let provider = try #require(kernel.resolveProvider((any DeveloperModeProviding).self))
        #expect(provider.isEnabled == false)
#if DEBUG
        #expect(toolbar.toolbarItems.count == 2)
        #expect(toolbar.toolbarItems.map(\.id) == ["\(plugin.id).toggle", "\(plugin.id).badge"])
#else
        #expect(toolbar.toolbarItems.count == 1)
#endif
        #expect(toolbar.toolbarItems[0].placement == .leading)
        #expect(toolbar.toolbarItems[0].id == "\(plugin.id).toggle")
        #expect(type(of: toolbar.toolbarItems[0].makeView()) == AnyView.self)
    }

    @Test("toolbar toggle updates the kernel provider")
    func toolbarToggleUpdatesProvider() throws {
        let kernel = KernelCoreContainer()
        let toolbar = DefaultToolbarProviding()
        try kernel.registerProvider((any ToolbarProviding).self, toolbar)
        try kernel.registerProvider((any DeveloperModeProviding).self, DefaultDeveloperModeProviding())

        try DeveloperModePlugin().onBoot(kernel: kernel)
        let provider = try #require(kernel.resolveProvider((any DeveloperModeProviding).self))
        provider.toggle()

        #expect(provider.isEnabled == true)
    }
}
