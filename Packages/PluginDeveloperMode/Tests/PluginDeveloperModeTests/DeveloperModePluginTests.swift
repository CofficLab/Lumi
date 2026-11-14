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
        // Debug 下只注册 toggle 一项。
        //
        // - Note: 曾经还有一项 `"\(plugin.id).badge"`（DebugBadgeView），
        //   已在 75ca0313a「remove debug badge from toolbar」中移除，
        //   但本断言未同步，导致测试恒定失败。
        #expect(toolbar.toolbarItems.count == 1)
        #expect(toolbar.toolbarItems.map(\.id) == ["\(plugin.id).toggle"])
        #expect(toolbar.toolbarItems[0].placement == .leading)
        #expect(toolbar.toolbarItems[0].id == "\(plugin.id).toggle")
        #expect(type(of: toolbar.toolbarItems[0].makeView()) == AnyView.self)
#else
        // Release 下整个 toggle 注册都在 `#if DEBUG` 内，一个工具栏项都不注册。
        // - Important: 这里不能断言 `count == 1`——那会让 Release 构建编译期
        //   留下 `toolbarItems[0]` 的越界访问。
        #expect(toolbar.toolbarItems.isEmpty)
#endif
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
