import Testing
import LumiCoreKit
@testable import PluginDiskManager

@MainActor
struct PluginDiskManagerTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(DiskManagerPlugin.id == "DiskManager")
        #expect(DiskManagerPlugin.navigationId == "disk_manager")
        #expect(DiskManagerPlugin.displayName.isEmpty == false)
        #expect(DiskManagerPlugin.description.isEmpty == false)
        #expect(DiskManagerPlugin.iconName == "internaldrive")
        #expect(DiskManagerPlugin.category == .system)
        #expect(DiskManagerPlugin.order == 22)
        #expect(DiskManagerPlugin.enable == true)
        #expect(DiskManagerPlugin.shared.instanceLabel == DiskManagerPlugin.id)
    }

    @Test
    func viewContainerContributionIsAvailable() {
        let item = DiskManagerPlugin.shared.addViewContainer()
        #expect(item?.id == DiskManagerPlugin.id)
        #expect(item?.title == DiskManagerPlugin.displayName)
        #expect(item?.icon == DiskManagerPlugin.iconName)
    }

    @Test
    func localizationCatalogIsPackaged() {
        #expect(PluginDiskManagerLocalization.bundle.url(forResource: "DiskManager", withExtension: "xcstrings") != nil)
        #expect(PluginDiskManagerLocalization.string("Disk Manager").isEmpty == false)
    }
}
