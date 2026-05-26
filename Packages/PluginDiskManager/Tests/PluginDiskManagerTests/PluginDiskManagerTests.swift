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
    func panelContributionMatchesActiveIcon() {
        #expect(DiskManagerPlugin.shared.addPanelIcon() == DiskManagerPlugin.iconName)
        #expect(DiskManagerPlugin.shared.addPanelView(activeIcon: "other") == nil)
        #expect(DiskManagerPlugin.shared.addPanelView(activeIcon: DiskManagerPlugin.iconName) != nil)
    }

    @Test
    func localizationCatalogIsPackaged() {
        #expect(PluginDiskManagerLocalization.bundle.url(forResource: "DiskManager", withExtension: "xcstrings") != nil)
        #expect(PluginDiskManagerLocalization.string("Disk Manager").isEmpty == false)
    }
}
