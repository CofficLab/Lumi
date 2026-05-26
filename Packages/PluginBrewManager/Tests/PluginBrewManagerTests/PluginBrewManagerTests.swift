import Testing
import LumiCoreKit
@testable import PluginBrewManager

@MainActor
struct PluginBrewManagerTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(BrewManagerPlugin.id == "BrewManager")
        #expect(BrewManagerPlugin.navigationId == "brew_manager")
        #expect(BrewManagerPlugin.displayName.isEmpty == false)
        #expect(BrewManagerPlugin.description.isEmpty == false)
        #expect(BrewManagerPlugin.iconName == "mug.fill")
        #expect(BrewManagerPlugin.category == .developerTool)
        #expect(BrewManagerPlugin.order == 60)
        #expect(BrewManagerPlugin.enable == false)
        #expect(BrewManagerPlugin.shared.instanceLabel == BrewManagerPlugin.id)
    }

    @Test
    func panelContributionMatchesActiveIcon() {
        #expect(BrewManagerPlugin.shared.addPanelIcon() == BrewManagerPlugin.iconName)
        #expect(BrewManagerPlugin.shared.addPanelView(activeIcon: "other") == nil)
        #expect(BrewManagerPlugin.shared.addPanelView(activeIcon: BrewManagerPlugin.iconName) != nil)
    }

    @Test
    func localizationCatalogIsPackaged() {
        #expect(PluginBrewManagerLocalization.bundle.url(forResource: "BrewManager", withExtension: "xcstrings") != nil)
        #expect(PluginBrewManagerLocalization.string("Package Management").isEmpty == false)
    }
}
