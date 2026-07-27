import Testing
import LumiKernel
@testable import AppLoadedPluginsPlugin

@MainActor
struct PluginAppLoadedPluginsTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(AppLoadedPluginsPlugin.id == "AppLoadedPlugins")
        #expect(AppLoadedPluginsPlugin.displayName.isEmpty == false)
        #expect(AppLoadedPluginsPlugin.description.isEmpty == false)
        #expect(AppLoadedPluginsPlugin.iconName == "puzzlepiece.extension")
        #expect(AppLoadedPluginsPlugin.isConfigurable == false)
        #expect(AppLoadedPluginsPlugin.category == .general)
        #expect(AppLoadedPluginsPlugin.order == 79)
        #expect(AppLoadedPluginsPlugin.policy == .disabled)
        #expect(AppLoadedPluginsPlugin.shared.instanceLabel == AppLoadedPluginsPlugin.id)
    }

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

    @Test
    func statusBarContributionUsesPluginProvider() {
        let originalProvider = AppLoadedPluginsPlugin.pluginProvider
        AppLoadedPluginsPlugin.pluginProvider = {
            [LoadedPluginInfo(id: "test", displayName: "Test", description: "desc", order: 1)]
        }
        defer { AppLoadedPluginsPlugin.pluginProvider = originalProvider }

        #expect(AppLoadedPluginsPlugin.shared.addStatusBarTrailingView(context: PluginContext()) != nil)
    }

    @Test
    func localizationCatalogIsPackaged() {
        #expect(PluginAppLoadedPluginsLocalization.bundle.url(forResource: "AppLoadedPlugins", withExtension: "xcstrings") != nil)
        #expect(PluginAppLoadedPluginsLocalization.string("App Plugins").isEmpty == false)
    }
}
