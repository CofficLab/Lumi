import Foundation
import KernelCore
import ProviderStorage
import ProviderTheme
import Testing

@testable import PluginThemeManager

@MainActor
@Suite("PluginThemeManager")
struct ThemeManagerPluginTests {
    @Test("插件注册 ThemeProviding 并使用自身 ID 目录")
    func registersThemeProviderInPluginDirectory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ThemeManagerPluginTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let storage = DefaultStorageProvider(dataRootDirectory: root)
        let kernel = KernelCoreContainer()
        try kernel.registerHostProvider((any StorageProviding).self, storage)
        let plugin = ThemeManagerPlugin()

        try kernel.start(plugins: [plugin])

        let theme = try #require(kernel.resolveProvider((any ThemeProviding).self))
        #expect(theme.themes.map(\.id) == ["lumi", "lumi-system", "lumi-dark", "lumi-light"])
        #expect(FileManager.default.fileExists(
            atPath: storage.pluginDataDirectory(for: plugin.id).path
        ))
    }

    @Test("保留当前 v6 ThemeManager 目录并迁移到插件 ID 目录")
    func migratesCurrentLegacyDirectory() throws {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("ThemeManagerMigrationTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        let currentRoot = parent.appendingPathComponent("db_production_v6", isDirectory: true)
        let storage = DefaultStorageProvider(dataRootDirectory: currentRoot)
        let oldDirectory = currentRoot.appendingPathComponent("ThemeManager", isDirectory: true)
        try FileManager.default.createDirectory(at: oldDirectory, withIntermediateDirectories: true)
        let oldSelection = oldDirectory.appendingPathComponent("theme-selection.plist")
        let plist = ["selectedThemeID": "lumi-dark"]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: oldSelection)

        let kernel = KernelCoreContainer()
        try kernel.registerHostProvider((any StorageProviding).self, storage)
        let plugin = ThemeManagerPlugin()
        let context = PluginDataMigrationContext(
            pluginID: plugin.id,
            currentMajorVersion: 6,
            currentDataRootDirectory: currentRoot,
            legacyDataRootDirectories: [:]
        )

        try plugin.migrateData(context: context)
        try kernel.start(plugins: [plugin])

        #expect(kernel.resolveProvider((any ThemeProviding).self)?.selectedThemeId == "lumi-dark")
        #expect(FileManager.default.fileExists(
            atPath: storage.pluginDataDirectory(for: plugin.id)
                .appendingPathComponent("theme-selection.plist").path
        ))
        #expect(FileManager.default.fileExists(atPath: oldSelection.path))
    }
}
