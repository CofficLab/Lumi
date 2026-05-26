import Testing
@testable import PluginDockerManager

struct PluginDockerManagerTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(DockerManagerPlugin.id == "DockerManager")
        #expect(DockerManagerPlugin.iconName == "shippingbox")
    }
}
