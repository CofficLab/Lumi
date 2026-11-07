import Foundation
import KernelCore
import Testing
@testable import ProviderStorage

/// `StorageDataMigration` 与版本根目录发现的契约测试。
///
/// 迁移采用复制而非移动：旧版本数据保留，目标中已有内容不被覆盖，
/// 完成后写入标记文件，保证中断后可安全重试且不重复复制。
@Suite("ProviderStorage migration")
@MainActor
struct StorageDataMigrationTests {

    private func makeVersionedRoots() throws -> (parent: URL, v4: URL, v5: URL, v6: URL) {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProviderStorageMigration-\(UUID().uuidString)", isDirectory: true)
        let v4 = parent.appendingPathComponent("db_production_v4", isDirectory: true)
        let v5 = parent.appendingPathComponent("db_production_v5", isDirectory: true)
        let v6 = parent.appendingPathComponent("db_production_v6", isDirectory: true)
        for url in [v4, v5, v6] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return (parent, v4, v5, v6)
    }

    // MARK: - StorageDataMigration

    @Test("从旧版本根目录复制同名与遗留目录，且保留源数据")
    func migrateCopiesLegacyAndSameNameDirectories() throws {
        let roots = try makeVersionedRoots()
        defer { try? FileManager.default.removeItem(at: roots.parent) }

        let legacyDir = roots.v5.appendingPathComponent("LegacyPlugin", isDirectory: true)
        try FileManager.default.createDirectory(at: legacyDir, withIntermediateDirectories: true)
        try Data("legacy".utf8).write(to: legacyDir.appendingPathComponent("history.db"))

        let sameIDDir = roots.v4.appendingPathComponent("com.example.plugin", isDirectory: true)
        try FileManager.default.createDirectory(at: sameIDDir, withIntermediateDirectories: true)
        try Data("same-id".utf8).write(to: sameIDDir.appendingPathComponent("state.json"))

        let storage = DefaultStorageProvider(dataRootDirectory: roots.v6)
        try StorageDataMigration.migrate(
            storage: storage,
            pluginID: "com.example.plugin",
            legacyDirectoryNames: ["LegacyPlugin"]
        )

        let destination = roots.v6.appendingPathComponent("com.example.plugin", isDirectory: true)
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("history.db").path))
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("state.json").path))
        #expect(FileManager.default.fileExists(atPath: legacyDir.appendingPathComponent("history.db").path), "复制不应删除旧版本数据")

        // 标记文件保证迁移可被识别为已完成。
        #expect(FileManager.default.fileExists(
            atPath: destination.appendingPathComponent(".lumi-storage-migration.json").path
        ))
    }

    @Test("多版本冲突时最新版本获胜，旧内容不被覆盖")
    func newestLegacyVersionWinsOnConflict() throws {
        let roots = try makeVersionedRoots()
        defer { try? FileManager.default.removeItem(at: roots.parent) }

        let v4Dir = roots.v4.appendingPathComponent("com.example.plugin", isDirectory: true)
        try FileManager.default.createDirectory(at: v4Dir, withIntermediateDirectories: true)
        try Data("v4".utf8).write(to: v4Dir.appendingPathComponent("settings.json"))

        let v5Dir = roots.v5.appendingPathComponent("com.example.plugin", isDirectory: true)
        try FileManager.default.createDirectory(at: v5Dir, withIntermediateDirectories: true)
        try Data("v5".utf8).write(to: v5Dir.appendingPathComponent("settings.json"))

        let storage = DefaultStorageProvider(dataRootDirectory: roots.v6)
        try StorageDataMigration.migrate(
            storage: storage,
            pluginID: "com.example.plugin",
            legacyDirectoryNames: []
        )

        let migrated = roots.v6.appendingPathComponent("com.example.plugin", isDirectory: true)
            .appendingPathComponent("settings.json")
        let content = try String(contentsOf: migrated, encoding: .utf8)
        #expect(content == "v5", "按版本降序复制时最新版本应优先")
    }

    @Test("迁移标记完成后再次迁移不重复复制")
    func completedMarkerSkipsSecondMigration() throws {
        let roots = try makeVersionedRoots()
        defer { try? FileManager.default.removeItem(at: roots.parent) }

        let legacyDir = roots.v5.appendingPathComponent("com.example.plugin", isDirectory: true)
        try FileManager.default.createDirectory(at: legacyDir, withIntermediateDirectories: true)
        try Data("first".utf8).write(to: legacyDir.appendingPathComponent("file.bin"))

        let storage = DefaultStorageProvider(dataRootDirectory: roots.v6)
        try StorageDataMigration.migrate(
            storage: storage,
            pluginID: "com.example.plugin",
            legacyDirectoryNames: []
        )

        // 第一次迁移后旧版本新增文件；再次迁移应被标记文件短路。
        try Data("second".utf8).write(to: legacyDir.appendingPathComponent("new-file.bin"))
        try StorageDataMigration.migrate(
            storage: storage,
            pluginID: "com.example.plugin",
            legacyDirectoryNames: []
        )

        let destination = roots.v6.appendingPathComponent("com.example.plugin", isDirectory: true)
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("file.bin").path))
        #expect(!FileManager.default.fileExists(atPath: destination.appendingPathComponent("new-file.bin").path))
    }

    @Test("没有可迁移的旧目录时不创建目标目录")
    func noLegacySourcesCreatesNothing() throws {
        let roots = try makeVersionedRoots()
        defer { try? FileManager.default.removeItem(at: roots.parent) }

        let storage = DefaultStorageProvider(dataRootDirectory: roots.v6)
        try StorageDataMigration.migrate(
            storage: storage,
            pluginID: "com.example.plugin",
            legacyDirectoryNames: ["MissingLegacy"]
        )

        let destination = roots.v6.appendingPathComponent("com.example.plugin", isDirectory: true)
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

    @Test("当前主版本号固定为 6")
    func currentMajorVersionIsPinned() {
        #expect(StorageDataMigration.currentMajorVersion == 6)
    }

    // MARK: - PluginDataMigrationRunner

    @Test("Runner 为非迁移插件复制同名旧目录")
    func runnerCopiesForNonMigratingPlugin() throws {
        let roots = try makeVersionedRoots()
        defer { try? FileManager.default.removeItem(at: roots.parent) }

        let legacyDir = roots.v5.appendingPathComponent("com.example.plain", isDirectory: true)
        try FileManager.default.createDirectory(at: legacyDir, withIntermediateDirectories: true)
        try Data("plain".utf8).write(to: legacyDir.appendingPathComponent("data.sqlite"))

        let storage = DefaultStorageProvider(dataRootDirectory: roots.v6)
        try PluginDataMigrationRunner(storage: storage).run(for: [PlainPlugin()])

        #expect(FileManager.default.fileExists(
            atPath: roots.v6.appendingPathComponent("com.example.plain").appendingPathComponent("data.sqlite").path
        ))
    }

    @Test("Runner 将正确的迁移上下文交给声明迁移的插件")
    func runnerPassesContextToMigratingPlugin() throws {
        let roots = try makeVersionedRoots()
        defer { try? FileManager.default.removeItem(at: roots.parent) }

        let legacyDir = roots.v5.appendingPathComponent("LegacyName", isDirectory: true)
        try FileManager.default.createDirectory(at: legacyDir, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: legacyDir.appendingPathComponent("file.txt"))

        let plugin = MigratingPlugin()
        let storage = DefaultStorageProvider(dataRootDirectory: roots.v6)
        try PluginDataMigrationRunner(storage: storage).run(for: [plugin])

        #expect(plugin.context?.pluginID == plugin.id)
        #expect(plugin.context?.currentMajorVersion == 6)
        #expect(plugin.context?.currentDataRootDirectory == roots.v6.standardizedFileURL)
        #expect(plugin.context?.legacyDataRootDirectories.keys.sorted() == [4, 5])
        #expect(plugin.context?.legacyPluginDataDirectory(named: "LegacyName", in: 5) == legacyDir)

        // 默认 migrateData 会把遗留目录复制到当前插件目录。
        #expect(FileManager.default.fileExists(
            atPath: roots.v6.appendingPathComponent(plugin.id).appendingPathComponent("file.txt").path
        ))
    }

    // MARK: - 版本发现边界

    @Test("版本发现只匹配当前环境的同名前缀")
    func discoveryIgnoresOtherEnvironmentPrefixes() throws {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProviderStoragePrefix-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        let debugRoot = parent.appendingPathComponent("db_debug_v3", isDirectory: true)
        let productionRoot = parent.appendingPathComponent("db_production_v6", isDirectory: true)
        try FileManager.default.createDirectory(at: debugRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: productionRoot, withIntermediateDirectories: true)

        let provider = DefaultStorageProvider(dataRootDirectory: productionRoot)

        #expect(provider.allVersionDataRootDirectories.map(\.lastPathComponent) == ["db_production_v6"])
    }

    @Test("版本发现忽略无关目录与同名文件")
    func discoveryIgnoresUnrelatedEntries() throws {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProviderStorageUnrelated-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        let root = parent.appendingPathComponent("db_debug_v2", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: parent.appendingPathComponent("Unrelated", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: parent.appendingPathComponent("db_debug_extra", isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data("file".utf8).write(to: parent.appendingPathComponent("db_debug_v9"))

        let provider = DefaultStorageProvider(dataRootDirectory: root)

        #expect(provider.allVersionDataRootDirectories.map(\.lastPathComponent) == ["db_debug_v2"])
    }

    @Test("版本发现始终包含当前根目录并去重")
    func discoveryIncludesCurrentRootAndDeduplicates() throws {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProviderStorageDedup-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        let root = parent.appendingPathComponent("db_debug_v4", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: parent.appendingPathComponent("db_debug_v1", isDirectory: true),
            withIntermediateDirectories: true
        )

        let provider = DefaultStorageProvider(dataRootDirectory: root)
        let roots = provider.allVersionDataRootDirectories

        #expect(roots.map(\.lastPathComponent) == ["db_debug_v1", "db_debug_v4"])
        #expect(roots.count == Set(roots.map(\.path)).count)
    }

    // MARK: - Fixtures

    private final class PlainPlugin: SuperPlugin {
        let id = "com.example.plain"
        var metadata: PluginMetadata { PluginMetadata(id: id) }
    }

    private final class MigratingPlugin: SuperPlugin, PluginDataMigrating {
        let id = "com.example.migrating"
        var metadata: PluginMetadata { PluginMetadata(id: id) }
        var legacyDataDirectoryNames: [String] { ["LegacyName"] }
        var context: PluginDataMigrationContext?
        var called = false

        func migrateData(context: PluginDataMigrationContext) throws {
            self.context = context
            called = true
            try PluginDataMigrationUtility.copyLegacyDirectories(
                legacyDirectoryNames: legacyDataDirectoryNames,
                context: context
            )
        }
    }
}
