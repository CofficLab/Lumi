import AgentToolKit
import LumiCoreKit
import Testing
@testable import PluginCaffeinate

@MainActor
struct PluginCaffeinateTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(CaffeinatePlugin.id == "Caffeinate")
        #expect(CaffeinatePlugin.navigationId == "caffeinate_settings")
        #expect(CaffeinatePlugin.displayName.isEmpty == false)
        #expect(CaffeinatePlugin.description.isEmpty == false)
        #expect(CaffeinatePlugin.iconName == "bolt")
        #expect(CaffeinatePlugin.isConfigurable == false)
        #expect(CaffeinatePlugin.category == .system)
        #expect(CaffeinatePlugin.order == 7)
        #expect(CaffeinatePlugin.policy == .disabled)
        #expect(CaffeinatePlugin.shared.instanceLabel == CaffeinatePlugin.id)
    }

    @Test
    func pluginRegistersCaffeinateTools() {
        let tools = CaffeinatePlugin.shared.agentTools(context: ToolContext())

        #expect(tools.map(\.name) == [
            "caffeinate_activate",
            "caffeinate_deactivate",
            "caffeinate_status",
            "caffeinate_turn_off_display",
        ])
        #expect(CaffeinatePlugin.shared.addMenuBarPopupView() != nil)
    }

    @Test
    func toolSchemasAndRiskLevelsAreStable() throws {
        let activate = CaffeinateActivateTool()
        let activateSchema = activate.inputSchema(for: .english)
        let activateProperties = try #require(activateSchema["properties"] as? [String: Any])
        #expect(activateProperties["mode"] != nil)
        #expect(activateProperties["duration"] != nil)
        #expect(activate.permissionRiskLevel(arguments: [:]) == .low)

        let turnOffDisplaySchema = CaffeinateTurnOffDisplayTool().inputSchema(for: .english)
        let turnOffDisplayProperties = try #require(turnOffDisplaySchema["properties"] as? [String: Any])
        #expect(turnOffDisplayProperties["duration"] != nil)

        #expect(CaffeinateDeactivateTool().permissionRiskLevel(arguments: [:]) == .low)
        #expect(CaffeinateStatusTool().permissionRiskLevel(arguments: [:]) == .low)
        #expect(CaffeinateTurnOffDisplayTool().permissionRiskLevel(arguments: [:]) == .low)
    }

    @Test
    func localizationCatalogIsPackaged() {
        #expect(PluginCaffeinateLocalization.bundle.url(forResource: "Caffeinate", withExtension: "xcstrings") != nil)
        #expect(PluginCaffeinateLocalization.string("Anti-Sleep").isEmpty == false)
    }
}
