import Testing
import Foundation
@testable import PluginHostsManager

@MainActor
struct PluginHostsManagerTests {
    @Test
    func pluginMetadataIsStable() {
        let plugin = HostsManagerPlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.hosts-manager")
        #expect(plugin.name.isEmpty == false)
        #expect(plugin.order == 21)
        #expect(plugin.metadata.policy == .disabledByDefault)
        #expect(plugin.metadata.category == .system)
        #expect(plugin.metadata.stage == .preview)
    }

    @Test
    func localizationCatalogIsPackaged() {
        let bundle = Bundle.module
        #expect(bundle.url(forResource: "Localizable", withExtension: "xcstrings") != nil)
        #expect(LumiPluginLocalization.string("Hosts Manager", bundle: .module).isEmpty == false)
    }
}
