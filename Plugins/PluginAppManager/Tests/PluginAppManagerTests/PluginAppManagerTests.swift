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
    func viewContainerContributionIsAvailable() {
        let item = AppManagerPlugin.shared.addViewContainer()
        #expect(item?.id == AppManagerPlugin.id)
        #expect(item?.title == AppManagerPlugin.displayName)
        #expect(item?.icon == AppManagerPlugin.iconName)
    }

    @Test
    func localizationCatalogIsPackaged() {
        #expect(PluginAppManagerLocalization.bundle.url(forResource: "AppManager", withExtension: "xcstrings") != nil)
        #expect(PluginAppManagerLocalization.string("App Manager").isEmpty == false)
    }

    @Test
    func directoryURLSupportsSpacesAndSpecialCharacters() {
        let url = AppService.directoryURL(forPath: "/tmp/Lumi App Manager/#Test Folder")

        #expect(url.isFileURL)
        #expect(url.path == "/tmp/Lumi App Manager/#Test Folder")
        #expect(url.absoluteString.contains("Lumi%20App%20Manager"))
        #expect(url.absoluteString.contains("%23Test%20Folder"))
    }
}
