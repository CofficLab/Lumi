import Testing
@testable import PluginDeviceInfo

@Test func pluginMetadata() async throws {
    #expect(DeviceInfoPlugin.id == "DeviceInfo")
    #expect(DeviceInfoPlugin.navigationId == "device_info")
    #expect(DeviceInfoPlugin.iconName == "macbook.and.iphone")
}
