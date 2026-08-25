import Foundation
import KernelCore
import ProviderTheme
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

        let plugin = WebServerPlugin()
        try plugin.onBoot(kernel: kernel)

        let server = try #require(kernel.resolveProvider((any WebServerProviding).self))
        #expect(server.port == 7310)
        #expect(server is LumiWebServer)
    }
}
