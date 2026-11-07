import KernelCore
import ProviderMenuBar
import Testing
@testable import PluginNetworkManager

@Suite("NetworkManager 菜单栏生命周期")
@MainActor
struct NetworkManagerMenuBarLifecycleTests {
    @Test("禁用自动撤回，重新启用恢复贡献")
    func disableAndEnableRestoresContributions() async throws {
        let kernel = KernelCoreContainer()
        let menuBar = DefaultMenuBarProviding()
        try kernel.registerProvider((any MenuBarProviding).self, menuBar)
        let plugin = NetworkManagerPlugin()
        try kernel.start(plugins: [plugin])

        #expect(menuBar.contentItems.map(\.id) == ["\(plugin.id).speed"])
        #expect(menuBar.popupItems.map(\.id) == ["\(plugin.id).popup"])

        try await kernel.disablePlugin(id: plugin.id)
        #expect(menuBar.contentItems.isEmpty)
        #expect(menuBar.popupItems.isEmpty)

        try await kernel.enablePlugin(id: plugin.id)
        #expect(menuBar.contentItems.map(\.id) == ["\(plugin.id).speed"])
        #expect(menuBar.popupItems.map(\.id) == ["\(plugin.id).popup"])

        try kernel.stop()
    }
}
