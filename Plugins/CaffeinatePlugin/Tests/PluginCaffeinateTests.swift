import LumiKernel
import Testing
@testable import CaffeinatePlugin

@MainActor
struct PluginCaffeinateTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(CaffeinatePlugin.id == "Caffeinate")
        #expect(CaffeinatePlugin.navigationId == "caffeinate_settings")
        #expect(CaffeinatePlugin.displayName.isEmpty == false)
        #expect(CaffeinatePlugin.description.isEmpty == false)
        #expect(CaffeinatePlugin.iconName == "bolt")
        #expect(CaffeinatePlugin.isConfigurable == true)
        #expect(CaffeinatePlugin.category == .system)
        #expect(CaffeinatePlugin.order == 7)
        #expect(CaffeinatePlugin.policy == .optOut)
    }

    @Test
    func pluginRegistersCaffeinateTools() {
        let tools = CaffeinatePlugin.agentTools(
            lumiCore: LumiPluginContext(activeSectionID: "test", activeSectionTitle: "Test")
        )

        #expect(tools.map(\.name) == [
            "caffeinate_activate",
            "caffeinate_deactivate",
            "caffeinate_status",
            "caffeinate_turn_off_display",
        ])
        #expect(CaffeinatePlugin.menuBarPopupItems(
            lumiCore: LumiPluginContext(activeSectionID: "test", activeSectionTitle: "Test")
        ).isEmpty == false)
    }

    @Test
    func toolSchemasAndRiskLevelsAreStable() {
        let activate = CaffeinateActivateTool()
        let activateProperties = Self.extractProperties(activate.inputSchema)
        #expect(activateProperties?["mode"] != nil)
        #expect(activateProperties?["duration"] != nil)
        #expect(activate.riskLevel(arguments: [:], context: nil) == .low)

        let turnOffDisplayProperties = Self.extractProperties(CaffeinateTurnOffDisplayTool().inputSchema)
        #expect(turnOffDisplayProperties?["duration"] != nil)

        #expect(CaffeinateDeactivateTool().riskLevel(arguments: [:], context: nil) == .low)
        #expect(CaffeinateStatusTool().riskLevel(arguments: [:], context: nil) == .low)
        #expect(CaffeinateTurnOffDisplayTool().riskLevel(arguments: [:], context: nil) == .low)
    }

    /// 从 LumiJSONValue schema 中提取 properties 对象。
    private static func extractProperties(_ schema: LumiJSONValue) -> [String: LumiJSONValue]? {
        guard case .object(let keys) = schema, case .object(let properties) = keys["properties"] else {
            return nil
        }
        return properties
    }

    @Test
    func localizationCatalogIsPackaged() {
        #expect(PluginCaffeinateLocalization.bundle.url(forResource: "Caffeinate", withExtension: "xcstrings") != nil)
        #expect(PluginCaffeinateLocalization.string("Anti-Sleep").isEmpty == false)
    }
}
