import Testing
import LumiCoreKit
@testable import PluginAppManager

@MainActor
struct PluginAppManagerTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(AppManagerPlugin.id == "AppManager")
        #expect(AppManagerPlugin.navigationId == "app_manager")
        #expect(AppManagerPlugin.displayName.isEmpty == false)
        #expect(AppManagerPlugin.description.isEmpty == false)
        #expect(AppManagerPlugin.iconName == "apps.ipad")
        #expect(AppManagerPlugin.category == .system)
        #expect(AppManagerPlugin.order == 40)
        #expect(AppManagerPlugin.enable == true)
        #expect(AppManagerPlugin.shared.instanceLabel == AppManagerPlugin.id)
    }

    @Test
    func panelContributionMatchesActiveIcon() {
        #expect(AppManagerPlugin.shared.addPanelIcon() == AppManagerPlugin.iconName)
        #expect(AppManagerPlugin.shared.addPanelView(activeIcon: "other") == nil)
        #expect(AppManagerPlugin.shared.addPanelView(activeIcon: AppManagerPlugin.iconName) != nil)
    }

    @Test
    func localizationCatalogIsPackaged() {
        #expect(PluginAppManagerLocalization.bundle.url(forResource: "AppManager", withExtension: "xcstrings") != nil)
        #expect(PluginAppManagerLocalization.string("App Manager").isEmpty == false)
    }
}
