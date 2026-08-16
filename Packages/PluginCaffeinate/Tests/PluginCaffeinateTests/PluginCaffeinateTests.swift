import AgentToolKit
import Foundation
import Testing
@testable import PluginCaffeinate

/// Metadata and contributor stability tests for the Caffeinate plugin.
@MainActor
struct PluginCaffeinateTests {
    @Test
    func pluginMetadataIsStable() {
        let plugin = CaffeinatePlugin()

        #expect(plugin.id == "Caffeinate")
        #expect(plugin.name.isEmpty == false)
        #expect(plugin.order == 1)
        #expect(plugin.metadata.policy == .enabledByDefault)
        #expect(plugin.metadata.category == .system)
        #expect(plugin.metadata.stage == .preview)
        #expect(plugin.metadata.description.isEmpty == false)
    }

    @Test
    func agentToolsExistAndHaveSchemas() {
        let activate = CaffeinateActivateTool()
        let activateProperties = activate.inputSchema(for: .english)["properties"] as? [String: Any]
        #expect(activateProperties?["mode"] != nil)
        #expect(activateProperties?["duration"] != nil)

        let turnOffDisplayProperties = CaffeinateTurnOffDisplayTool()
            .inputSchema(for: .english)["properties"] as? [String: Any]
        #expect(turnOffDisplayProperties?["duration"] != nil)

        // 只读/系统级工具均为低风险（旧版 riskLevel == .low）。
        #expect(CaffeinateActivateTool().permissionRiskLevel(arguments: [:]) == .low)
        #expect(CaffeinateDeactivateTool().permissionRiskLevel(arguments: [:]) == .low)
        #expect(CaffeinateStatusTool().permissionRiskLevel(arguments: [:]) == .low)
        #expect(CaffeinateTurnOffDisplayTool().permissionRiskLevel(arguments: [:]) == .low)
    }

    @Test
    func pluginRegistersAgentTools() {
        let names = CaffeinatePlugin.agentTools.map(\.name)

        #expect(CaffeinatePlugin.agentTools.count == 4)
        #expect(names == [
            "caffeinate_activate",
            "caffeinate_deactivate",
            "caffeinate_status",
            "caffeinate_turn_off_display",
        ])
    }

    @Test
    func localizationCatalogIsPackaged() {
        let bundle = Bundle.module
        #expect(bundle.url(forResource: "Localizable", withExtension: "xcstrings") != nil)
        #expect(LumiPluginLocalization.string("Caffeinate", bundle: .module).isEmpty == false)
    }
}
