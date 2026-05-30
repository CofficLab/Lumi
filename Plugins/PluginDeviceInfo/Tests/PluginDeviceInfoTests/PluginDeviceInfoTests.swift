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
        let item = DeviceInfoPlugin.shared.addViewContainer()
        #expect(item?.id == DeviceInfoPlugin.id)
        #expect(item?.title == DeviceInfoPlugin.displayName)
        #expect(item?.icon == DeviceInfoPlugin.iconName)
        #expect(DeviceInfoPlugin.shared.addMenuBarContentView() != nil)
        #expect(DeviceInfoPlugin.shared.addMenuBarPopupViews().count == 2)
    }

    @Test
    func localizationCatalogIsPackaged() {
        #expect(PluginDeviceInfoLocalization.bundle.url(forResource: "DeviceInfo", withExtension: "xcstrings") != nil)
        #expect(PluginDeviceInfoLocalization.string("Device Info").isEmpty == false)
    }

    @Test
    func deviceDataUsesInjectedCPUUsageProvider() {
        let counter = DeviceDataMonitorCounter()
        let data = DeviceData(
            cpuUsageProvider: { 73.5 },
            cpuMonitoringStarter: { counter.starts += 1 },
            cpuMonitoringStopper: { counter.stops += 1 }
        )

        #expect(data.cpuUsage == 73.5)
        #expect(counter.starts == 1)

        data.startMonitoring()
        #expect(counter.starts == 1)

        data.stopMonitoring()
        data.stopMonitoring()
        #expect(counter.stops == 1)
    }
}

@MainActor
private final class DeviceDataMonitorCounter {
    var starts = 0
    var stops = 0
}
