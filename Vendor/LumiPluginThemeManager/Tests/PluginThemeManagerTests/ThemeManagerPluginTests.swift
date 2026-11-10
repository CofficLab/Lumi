import Foundation
import KernelCore
import ProviderStorage
import ProviderTheme
import Testing

@testable import PluginThemeManager

// MARK: - 注册与配置

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

    @Test("自定义 id 透传到实例、元数据与持久化目录")
    func customIDIsApplied() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ThemeManagerCustomIDTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let storage = DefaultStorageProvider(dataRootDirectory: root)
        let kernel = KernelCoreContainer()
        try kernel.registerHostProvider((any StorageProviding).self, storage)
        let plugin = ThemeManagerPlugin(id: "com.example.custom.plugin.theme-manager")

        try kernel.start(plugins: [plugin])

        #expect(plugin.id == "com.example.custom.plugin.theme-manager")
        #expect(plugin.metadata.id == plugin.id)
        #expect(FileManager.default.fileExists(
            atPath: storage.pluginDataDirectory(for: "com.example.custom.plugin.theme-manager").path
        ))
        // 默认 id 与元数据本地化
        #expect(ThemeManagerPlugin.defaultPluginID == "com.coffic.lumi.plugin.theme-manager")
        #expect(!plugin.metadata.name.isEmpty)
        #expect(!plugin.metadata.description.isEmpty)
    }

    @Test("StorageProviding 缺失时 onBoot 抛错")
    func bootThrowsWithoutStorage() {
        let kernel = KernelCoreContainer()
        let plugin = ThemeManagerPlugin()
        #expect(throws: (any Error).self) {
            try kernel.start(plugins: [plugin])
        }
    }
}

// MARK: - 数据迁移

@MainActor
@Suite("ThemeManagerPlugin 数据迁移")
struct ThemeManagerMigrationTests {

    private func makeContext(
        pluginID: String,
        currentRoot: URL,
        legacyRoots: [Int: URL] = [:]
    ) -> PluginDataMigrationContext {
        PluginDataMigrationContext(
            pluginID: pluginID,
            currentMajorVersion: 4,
            currentDataRootDirectory: currentRoot,
            legacyDataRootDirectories: legacyRoots
        )
    }

    private func makeTempRoot() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ThemeManagerMigration-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// 从旧目录名 ThemeManager 迁移到插件 ID 目录（版本目录之间）。
    @Test("从旧目录名 ThemeManager 迁移到插件 ID 目录")
    func migratesFromLegacyDirectoryName() throws {
        let bundleRoot = makeTempRoot()
        defer { try? FileManager.default.removeItem(at: bundleRoot) }
        let currentRoot = bundleRoot.appendingPathComponent("db_debug_v4", isDirectory: true)
        let legacyRoot = bundleRoot.appendingPathComponent("db_debug_v3", isDirectory: true)

        let legacyThemeDir = legacyRoot.appendingPathComponent("ThemeManager", isDirectory: true)
        try FileManager.default.createDirectory(at: legacyThemeDir, withIntermediateDirectories: true)
        try Data("plist".utf8).write(to: legacyThemeDir.appendingPathComponent("theme-selection.plist"))

        let plugin = ThemeManagerPlugin()
        try plugin.migrateData(context: makeContext(
            pluginID: plugin.id, currentRoot: currentRoot, legacyRoots: [3: legacyRoot]
        ))

        let migrated = currentRoot
            .appendingPathComponent(plugin.id, isDirectory: true)
            .appendingPathComponent("theme-selection.plist")
        #expect(FileManager.default.fileExists(atPath: migrated.path))
    }

    /// Lumi 6.0.0 早期构建：同版本根内的 ThemeManager 目录。
    @Test("保留当前版本根 ThemeManager 目录并迁移到插件 ID 目录")
    func migratesCurrentLegacyDirectory() throws {
        let bundleRoot = makeTempRoot()
        defer { try? FileManager.default.removeItem(at: bundleRoot) }
        let currentRoot = bundleRoot.appendingPathComponent("db_production_v6", isDirectory: true)

        let oldDirectory = currentRoot.appendingPathComponent("ThemeManager", isDirectory: true)
        try FileManager.default.createDirectory(at: oldDirectory, withIntermediateDirectories: true)
        let oldSelection = oldDirectory.appendingPathComponent("theme-selection.plist")
        let plist = ["selectedThemeID": "lumi-dark"]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: oldSelection)

        let plugin = ThemeManagerPlugin()
        try plugin.migrateData(context: makeContext(pluginID: plugin.id, currentRoot: currentRoot))

        let migrated = currentRoot
            .appendingPathComponent(plugin.id, isDirectory: true)
            .appendingPathComponent("theme-selection.plist")
        #expect(FileManager.default.fileExists(atPath: migrated.path))
        // merge 语义：源目录保留
        #expect(FileManager.default.fileExists(atPath: oldSelection.path))
    }

    /// 早期 Kuzee 布局：数据根父级的非版本化 ThemeManager 目录。
    @Test("从非版本化的旧目录迁移（早期 Kuzee 布局）")
    func migratesFromUnversionedLegacyDirectory() throws {
        let bundleRoot = makeTempRoot()
        defer { try? FileManager.default.removeItem(at: bundleRoot) }
        let currentRoot = bundleRoot.appendingPathComponent("db_debug_v4", isDirectory: true)

        let unversioned = bundleRoot.appendingPathComponent("ThemeManager", isDirectory: true)
        try FileManager.default.createDirectory(at: unversioned, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: unversioned.appendingPathComponent("theme-selection.plist"))

        let plugin = ThemeManagerPlugin(id: "com.coffic.kuzee.plugin.theme-manager")
        try plugin.migrateData(context: makeContext(pluginID: plugin.id, currentRoot: currentRoot))

        let migrated = currentRoot
            .appendingPathComponent(plugin.id, isDirectory: true)
            .appendingPathComponent("theme-selection.plist")
        #expect(FileManager.default.fileExists(atPath: migrated.path))
    }
}
