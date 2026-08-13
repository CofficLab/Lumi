import Foundation
import KernelLumi
import Testing
@testable import CaffeinatePlugin

/// Metadata and contributor stability tests for the Caffeinate plugin.
///
/// Note: these tests assert the *current* `LumiPlugin` contract
/// (`viewContainers`, `menuBarPopupItems`, `pluginAboutView`). Earlier
/// iterations of this file referenced a now-removed
/// `LumiPluginContext` / `navigationId` / `isConfigurable` API surface.
@MainActor
struct PluginCaffeinateTests {
    @Test
    func pluginMetadataIsStable() {
        let plugin = CaffeinatePlugin()

        #expect(plugin.id == "Caffeinate")
        #expect(plugin.name.isEmpty == false)
        #expect(plugin.order == 1)
        #expect(plugin.policy == .alwaysOn)
        #expect(plugin.category == .system)
        #expect(plugin.stage == .beta)
        #expect(plugin.pluginDescription.isEmpty == false)
    }

    @Test
    func pluginExposesMenuBarPopupItem() {
        let plugin = CaffeinatePlugin()
        let popups = plugin.menuBarPopupItems(kernel: KernelLumi())

        #expect(popups.count == 1)
        #expect(popups.first?.id == "Caffeinate.popup")
    }

    @Test
    func pluginExposesViewContainer() {
        let plugin = CaffeinatePlugin()
        let containers = plugin.viewContainers(kernel: KernelLumi())

        #expect(containers.count == 1)
        #expect(containers.first?.id == "Caffeinate.container")
        #expect(containers.first?.systemImage.isEmpty == false)
    }

    @Test
    func pluginProvidesAboutView() {
        let plugin = CaffeinatePlugin()

        #expect(plugin.pluginAboutView(kernel: KernelLumi()) != nil)
    }

    @Test
    func agentToolsExistAndHaveSchemas() {
        let activate = CaffeinateActivateTool()
        let activateProperties = Self.extractProperties(activate.inputSchema)
        #expect(activateProperties?["mode"] != nil)
        #expect(activateProperties?["duration"] != nil)

        let turnOffDisplayProperties = Self.extractProperties(
            CaffeinateTurnOffDisplayTool().inputSchema
        )
        #expect(turnOffDisplayProperties?["duration"] != nil)

        // Risk level assertions use the modern `riskLevel(arguments:kernel:)` signature.
        let kernel = KernelLumi()
        #expect(CaffeinateActivateTool().riskLevel(arguments: [:], kernel: kernel) == .low)
        #expect(CaffeinateDeactivateTool().riskLevel(arguments: [:], kernel: kernel) == .low)
        #expect(CaffeinateStatusTool().riskLevel(arguments: [:], kernel: kernel) == .low)
        #expect(CaffeinateTurnOffDisplayTool().riskLevel(arguments: [:], kernel: kernel) == .low)
    }

    @Test
    func pluginRegistersAgentTools() {
        let tools = CaffeinatePlugin().agentTools(kernel: KernelLumi())

        #expect(tools.count == 4)
        #expect(tools.map(\.name) == [
            "caffeinate_activate",
            "caffeinate_deactivate",
            "caffeinate_status",
            "caffeinate_turn_off_display",
        ])
    }

    /// 从 `LumiJSONValue` schema 中提取 `properties` 字典。
    private static func extractProperties(_ schema: LumiJSONValue) -> [String: LumiJSONValue]? {
        guard case .object(let keys) = schema,
              case .object(let properties) = keys["properties"] else {
            return nil
        }
        return properties
    }

    @Test
    func localizationCatalogIsPackaged() {
        let bundle = Bundle.module
        #expect(bundle.url(forResource: "Localizable", withExtension: "xcstrings") != nil)
        #expect(LumiPluginLocalization.string("Caffeinate", bundle: .module).isEmpty == false)
    }
}