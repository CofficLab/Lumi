import Foundation
import KernelCore
import ProviderTheme
import ProviderSettingView
import ProviderWebServer
import Testing
import KitWebServer
@testable import PluginWebServer

@MainActor
@Suite("PluginWebServer")
struct WebServerPluginTests {
    @Test("启动时以真实服务替换默认 WebServer Provider，并注册旧主题路由")
    func installsServerAndRoutes() throws {
        let kernel = KernelCoreContainer()
        let theme = DefaultThemeProviding()
        try kernel.registerProvider((any ThemeProviding).self, theme)
        try kernel.registerProvider((any WebServerProviding).self, DefaultWebServerProviding())
        let settings = DefaultSettingViewProviding()
        try kernel.registerProvider((any SettingViewProviding).self, settings)

        let plugin = WebServerPlugin()
        try plugin.onBoot(kernel: kernel)

        let server = try #require(kernel.resolveProvider((any WebServerProviding).self))
        #expect(server.port == 7310)
        #expect(server is LumiWebServer)
        #expect(settings.entries.contains { $0.id == "com.coffic.lumi.plugin.web-server.settings" })
    }

    @Test("按插件统计的路由数与服务器实际注册一致")
    func routeCountsByPluginMatchesRegisteredRoutes() throws {
        let kernel = KernelCoreContainer()
        let theme = DefaultThemeProviding()
        try kernel.registerProvider((any ThemeProviding).self, theme)
        try kernel.registerProvider((any WebServerProviding).self, DefaultWebServerProviding())
        let settings = DefaultSettingViewProviding()
        try kernel.registerProvider((any SettingViewProviding).self, settings)

        let plugin = WebServerPlugin()
        try plugin.onBoot(kernel: kernel)

        let server = try #require(
            kernel.resolveProvider((any WebServerProviding).self) as? LumiWebServer
        )
        let counts = WebServerPlugin.routeCountsByPlugin(server: server)

        // Boot 阶段只注册核心控制面 10 条路由：无 ToolManager 时没有工具桥接，
        // 主题贡献要到 onReady 才下发。
        #expect(counts["com.coffic.lumi.plugin.web-server"] == 10)
        #expect(counts.values.reduce(0, +) == server.registeredRouteCount)
    }
}
