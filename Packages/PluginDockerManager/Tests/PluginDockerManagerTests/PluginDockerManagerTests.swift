import Testing
import LumiCoreKit
@testable import PluginDockerManager

@MainActor
struct PluginDockerManagerTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(DockerManagerPlugin.id == "DockerManager")
        #expect(DockerManagerPlugin.navigationId == "docker_manager")
        #expect(DockerManagerPlugin.displayName.isEmpty == false)
        #expect(DockerManagerPlugin.description.isEmpty == false)
        #expect(DockerManagerPlugin.iconName == "shippingbox")
        #expect(DockerManagerPlugin.category == .developerTool)
        #expect(DockerManagerPlugin.order == 50)
        #expect(DockerManagerPlugin.enable == false)
        #expect(DockerManagerPlugin.shared.instanceLabel == DockerManagerPlugin.id)
    }

    @Test
    func panelContributionMatchesActiveIcon() {
        #expect(DockerManagerPlugin.shared.addPanelIcon() == DockerManagerPlugin.iconName)
        #expect(DockerManagerPlugin.shared.addPanelView(activeIcon: "other") == nil)
        #expect(DockerManagerPlugin.shared.addPanelView(activeIcon: DockerManagerPlugin.iconName) != nil)
    }

    @Test
    func localizationCatalogIsPackaged() {
        #expect(PluginDockerManagerLocalization.bundle.url(forResource: "DockerManager", withExtension: "xcstrings") != nil)
        #expect(PluginDockerManagerLocalization.string("Docker").isEmpty == false)
    }
}
