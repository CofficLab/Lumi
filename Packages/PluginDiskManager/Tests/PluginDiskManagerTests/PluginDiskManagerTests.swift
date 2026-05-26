import Testing
@testable import PluginDiskManager

@Test func pluginMetadata() async throws {
    #expect(DiskManagerPlugin.id == "DiskManager")
    #expect(DiskManagerPlugin.navigationId == "disk_manager")
    #expect(DiskManagerPlugin.iconName == "internaldrive")
}
