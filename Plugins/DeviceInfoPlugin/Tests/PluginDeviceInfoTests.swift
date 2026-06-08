import Testing
import LumiCoreKit
@testable import DeviceInfoPlugin

@MainActor
struct PluginDeviceInfoTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(DeviceInfoPlugin.info.id == "com.coffic.lumi.plugin.device-info")
        #expect(DeviceInfoPlugin.info.displayName == "Device Info")
        #expect(DeviceInfoPlugin.info.description.isEmpty == false)
        #expect(DeviceInfoPlugin.iconName == "macbook.and.iphone")
        #expect(DeviceInfoPlugin.info.order == 20)
    }

    @Test
    func viewContainerIsProvided() {
        let items = DeviceInfoPlugin.viewContainers(
            context: LumiPluginContext(
                activeSectionID: "workspace",
                activeSectionTitle: "Workspace"
            )
        )

        #expect(items.count == 1)
        #expect(items.first?.id == DeviceInfoPlugin.info.id)
        #expect(items.first?.title == DeviceInfoPlugin.info.displayName)
        #expect(items.first?.systemImage == DeviceInfoPlugin.iconName)
    }
}
