import Testing
@testable import PluginAppLoadedPlugins

@MainActor
struct PluginAppLoadedPluginsTests {
    @Test
    func pluginProviderSortsByOrderThenName() {
        let viewModel = AppLoadedPluginsViewModel {
            [
                LoadedPluginInfo(id: "b", displayName: "Beta", description: "", order: 2),
                LoadedPluginInfo(id: "a", displayName: "Alpha", description: "", order: 1),
            ]
        }

        viewModel.refresh()

        #expect(viewModel.enabledPlugins.map(\.id) == ["a", "b"])
    }
}
