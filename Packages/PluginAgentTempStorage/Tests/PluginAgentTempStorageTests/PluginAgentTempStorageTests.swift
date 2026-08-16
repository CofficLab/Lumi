import AgentToolKit
import Testing
import Foundation
@testable import PluginAgentTempStorage

@MainActor
struct PluginAgentTempStorageTests {
    @Test
    func pluginMetadataIsStable() {
        let plugin = AgentTempStoragePlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.agent-temp-storage")
        #expect(plugin.name.isEmpty == false)
        #expect(plugin.order == 80)
        #expect(plugin.metadata.policy == .enabledByDefault)
        #expect(plugin.metadata.category == .system)
        #expect(plugin.metadata.stage == .preview)
    }

    @Test
    func pluginRegistersThreeTools() {
        let names = AgentTempStoragePlugin.agentTools.map(\.name)
        #expect(names == ["list_temp_files", "read_temp_file", "write_temp_file"])
    }

    @Test
    func toolsAreLowRisk() {
        for tool in AgentTempStoragePlugin.agentTools {
            #expect(tool.permissionRiskLevel(arguments: [:]) == .low)
        }
    }

    @Test
    func localizationCatalogIsPackaged() {
        let bundle = Bundle.module
        #expect(bundle.url(forResource: "Localizable", withExtension: "xcstrings") != nil)
        #expect(LumiPluginLocalization.string("Agent Temp Storage", bundle: .module).isEmpty == false)
    }
}
