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
        #expect(BrewManagerPlugin.enable == true)
        #expect(BrewManagerPlugin.shared.instanceLabel == BrewManagerPlugin.id)
    }

    @Test
    func viewContainerContributionIsAvailable() {
        let item = BrewManagerPlugin.shared.addViewContainer()
        #expect(item?.id == BrewManagerPlugin.id)
        #expect(item?.title == BrewManagerPlugin.displayName)
        #expect(item?.icon == BrewManagerPlugin.iconName)
    }

    @Test
    func localizationCatalogIsPackaged() {
        #expect(PluginBrewManagerLocalization.bundle.url(forResource: "BrewManager", withExtension: "xcstrings") != nil)
        #expect(PluginBrewManagerLocalization.string("Package Management").isEmpty == false)
    }
}
