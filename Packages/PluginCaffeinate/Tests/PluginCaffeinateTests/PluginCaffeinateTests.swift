import KitAgentTool
import Foundation
import ProviderStorage
import Testing
@testable import PluginCaffeinate

/// Metadata and contributor stability tests for the Caffeinate plugin.
@MainActor
struct PluginCaffeinateTests {
    @Test
    func pluginMetadataIsStable() {
        let plugin = CaffeinatePlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.caffeinate")
        #expect(plugin.name.isEmpty == false)
        #expect(plugin.order == 1)
        // 与 `CaffeinatePlugin.metadata` 保持一致：
        // 防休眠是系统级能力，因此 policy 为 `.required`、category 为 `.integration`、
        // stage 已是 `.stable`（不再是 preview）。
        #expect(plugin.metadata.id == "com.coffic.lumi.plugin.caffeinate")
        #expect(plugin.metadata.name == "Caffeinate")
        #expect(plugin.metadata.policy == .required)
        #expect(plugin.metadata.category == .integration)
        #expect(plugin.metadata.stage == .stable)
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
        // `.xcstrings` 是**源**目录里的文件；SPM 打包时会被编译成各语言的
        // `Localizable.strings`（`<lang>.lproj/Localizable.strings`），
        // 原始 `.xcstrings` 不会进 bundle。只查 `.xcstrings` 恒为 nil。
        let hasCatalog = bundle.url(forResource: "Localizable", withExtension: "xcstrings") != nil
        let hasCompiledStrings = bundle.path(forResource: "zh-Hans", ofType: "lproj") != nil
        #expect(hasCatalog || hasCompiledStrings)
        #expect(pluginLocalization.string("Caffeinate").isEmpty == false)
    }
}

@MainActor
struct CaffeinateLocalStoreMigrationTests {
    @Test
    func migratesLegacyStorageToPluginIDDirectory() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("PluginCaffeinateMigration-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        let legacySettingsDirectory = root
            .appendingPathComponent("Caffeinate", isDirectory: true)
            .appendingPathComponent("settings", isDirectory: true)
        try fileManager.createDirectory(at: legacySettingsDirectory, withIntermediateDirectories: true)

        let legacySettings = try PropertyListSerialization.data(
            fromPropertyList: ["defaultMode": "indefinite"],
            format: .binary,
            options: 0
        )
        try legacySettings.write(
            to: legacySettingsDirectory.appendingPathComponent("settings.plist"),
            options: .atomic
        )

        let storage = DefaultStorageProvider(dataRootDirectory: root)
        let store = CaffeinateLocalStore()
        store.configure(storage: storage)

        let migratedSettings = storage
            .pluginDataDirectory(for: CaffeinatePlugin.pluginID)
            .appendingPathComponent("settings/settings.plist")
        #expect(fileManager.fileExists(atPath: migratedSettings.path))
        #expect(!fileManager.fileExists(atPath: root.appendingPathComponent("Caffeinate").path))
        #expect(store.defaultModeRaw == "indefinite")
    }
}
