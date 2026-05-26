import Testing
import LumiCoreKit
@testable import PluginDeviceInfo

@MainActor
struct PluginDeviceInfoTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(DeviceInfoPlugin.id == "DeviceInfo")
        #expect(DeviceInfoPlugin.navigationId == "device_info")
        #expect(DeviceInfoPlugin.displayName.isEmpty == false)
        #expect(DeviceInfoPlugin.description.isEmpty == false)
        #expect(DeviceInfoPlugin.iconName == "macbook.and.iphone")
        #expect(DeviceInfoPlugin.isConfigurable == false)
        #expect(DeviceInfoPlugin.category == .general)
        #expect(DeviceInfoPlugin.order == 10)
        #expect(DeviceInfoPlugin.enable == true)
        #expect(DeviceInfoPlugin.shared.instanceLabel == DeviceInfoPlugin.id)
    }

    @Test
    func uiContributionsAreProvided() {
        #expect(DeviceInfoPlugin.shared.addPanelIcon() == DeviceInfoPlugin.iconName)
        #expect(DeviceInfoPlugin.shared.addPanelView(activeIcon: "other") == nil)
        #expect(DeviceInfoPlugin.shared.addPanelView(activeIcon: DeviceInfoPlugin.iconName) != nil)
        #expect(DeviceInfoPlugin.shared.addMenuBarContentView() != nil)
        #expect(DeviceInfoPlugin.shared.addMenuBarPopupViews().count == 2)
    }

    @Test
    func localizationCatalogIsPackaged() {
        #expect(PluginDeviceInfoLocalization.bundle.url(forResource: "DeviceInfo", withExtension: "xcstrings") != nil)
        #expect(PluginDeviceInfoLocalization.string("Device Info").isEmpty == false)
    }
}
