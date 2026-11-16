import Foundation
import KernelCore
import Testing
@testable import PluginAgentTempStorage

/// 为每个用例提供独立的临时目录。
private struct TempDirectory {
    let url: URL

    init() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentTempStorageMigrationTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: url)
    }
}

/// 回归 #811：保留天数是独立于旧文件目录的 UserDefaults 配置。
/// 仅升级「版本目录」（无版本旧目录不存在）时，配置导入不得被目录守卫短路，
/// 否则用户配置的保留天数会静默回退到默认 7 天，后续清理可能误删文件。
///
/// - Note: `.serialized`：本组用例会改写同一个全局注入位，必须串行执行。
@Suite("临时存储数据迁移", .serialized)
@MainActor
struct AgentTempStorageMigrationTests {

    private static let legacyKey = "AgentTempStorage.retentionDays"
    private static let pluginID = "com.coffic.lumi.plugin.agent-temp-storage"

    /// 注入假的旧 UserDefaults 域，替换测试进程里取不到的 app 持久化域。
    private func withLegacyDomain(_ domain: [String: Any]?, _ body: () throws -> Void) rethrows {
        let previous = AgentTempStoragePlugin.legacyDefaultsDomainProvider
        AgentTempStoragePlugin.legacyDefaultsDomainProvider = { domain }
        defer { AgentTempStoragePlugin.legacyDefaultsDomainProvider = previous }
        try body()
    }

    /// 注入无版本旧目录的根，确定性地控制 `<root>/AgentTempStorage` 是否存在。
    private func withLegacyFallbackRoot(_ root: URL, _ body: () throws -> Void) rethrows {
        let previous = AgentTempStoragePlugin.legacyFallbackRootDirectoryProvider
        AgentTempStoragePlugin.legacyFallbackRootDirectoryProvider = { root }
        defer { AgentTempStoragePlugin.legacyFallbackRootDirectoryProvider = previous }
        try body()
    }

    private func makeContext(root: URL, legacyRoots: [Int: URL] = [:]) -> PluginDataMigrationContext {
        PluginDataMigrationContext(
            pluginID: Self.pluginID,
            currentMajorVersion: 6,
            currentDataRootDirectory: root,
            legacyDataRootDirectories: legacyRoots
        )
    }

    private func settingsDirectory(in root: URL) -> URL {
        root.appendingPathComponent(Self.pluginID, isDirectory: true)
    }

    @Test("仅有版本目录升级时仍导入旧保留天数（#811）")
    func importsRetentionDaysWhenOnlyVersionedDirectoryExists() throws {
        let temp = TempDirectory()
        defer { temp.cleanup() }

        // 版本旧目录存在并含一个临时文件；无版本旧目录不存在。
        let versioned = temp.url.appendingPathComponent("v5/AgentTempStorage", isDirectory: true)
        try FileManager.default.createDirectory(at: versioned, withIntermediateDirectories: true)
        try "keep".write(to: versioned.appendingPathComponent("keep.md"), atomically: true, encoding: .utf8)
        let fallbackRoot = temp.url.appendingPathComponent("fallback", isDirectory: true)
        try FileManager.default.createDirectory(at: fallbackRoot, withIntermediateDirectories: true)

        let currentRoot = temp.url.appendingPathComponent("current", isDirectory: true)
        let plugin = AgentTempStoragePlugin()
        try withLegacyFallbackRoot(fallbackRoot) {
            try withLegacyDomain([Self.legacyKey: 14]) {
                try plugin.migrateData(
                    context: makeContext(root: currentRoot, legacyRoots: [5: temp.url.appendingPathComponent("v5")])
                )
            }
        }

        let directory = settingsDirectory(in: currentRoot)
        let store = AgentTempStoragePluginLocalStore(settingsDirectory: directory)
        // 配置必须按旧值 14 导入，而不是静默回退到默认 7。
        #expect(try store.resolvedRetentionDays() == 14)
        #expect(store.retentionDays == 14)
        // 版本目录里的文件确实被迁移（证明走的是「仅版本目录」升级路径）。
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("keep.md").path))
    }

    @Test("没有任何旧目录时仍导入旧保留天数")
    func importsRetentionDaysWhenNoLegacyDirectoryExists() throws {
        let temp = TempDirectory()
        defer { temp.cleanup() }
        let fallbackRoot = temp.url.appendingPathComponent("fallback", isDirectory: true)
        try FileManager.default.createDirectory(at: fallbackRoot, withIntermediateDirectories: true)

        let currentRoot = temp.url.appendingPathComponent("current", isDirectory: true)
        let plugin = AgentTempStoragePlugin()
        try withLegacyFallbackRoot(fallbackRoot) {
            try withLegacyDomain([Self.legacyKey: 30]) {
                try plugin.migrateData(context: makeContext(root: currentRoot))
            }
        }

        let store = AgentTempStoragePluginLocalStore(settingsDirectory: settingsDirectory(in: currentRoot))
        #expect(try store.resolvedRetentionDays() == 30)
    }

    @Test("插件存储已有配置时不被旧值覆盖")
    func doesNotOverwriteExistingSettings() throws {
        let temp = TempDirectory()
        defer { temp.cleanup() }
        let fallbackRoot = temp.url.appendingPathComponent("fallback", isDirectory: true)
        try FileManager.default.createDirectory(at: fallbackRoot, withIntermediateDirectories: true)

        let currentRoot = temp.url.appendingPathComponent("current", isDirectory: true)
        let directory = settingsDirectory(in: currentRoot)
        AgentTempStoragePluginLocalStore(settingsDirectory: directory).retentionDays = 21

        let plugin = AgentTempStoragePlugin()
        try withLegacyFallbackRoot(fallbackRoot) {
            try withLegacyDomain([Self.legacyKey: 14]) {
                try plugin.migrateData(context: makeContext(root: currentRoot))
            }
        }

        let store = AgentTempStoragePluginLocalStore(settingsDirectory: directory)
        #expect(try store.resolvedRetentionDays() == 21)
    }

    @Test("没有旧保留天数时不导入，保持默认")
    func skipsImportWhenNoLegacyValue() throws {
        let temp = TempDirectory()
        defer { temp.cleanup() }
        let fallbackRoot = temp.url.appendingPathComponent("fallback", isDirectory: true)
        try FileManager.default.createDirectory(at: fallbackRoot, withIntermediateDirectories: true)

        let currentRoot = temp.url.appendingPathComponent("current", isDirectory: true)
        let plugin = AgentTempStoragePlugin()
        try withLegacyFallbackRoot(fallbackRoot) {
            try withLegacyDomain([:]) {
                try plugin.migrateData(context: makeContext(root: currentRoot))
            }
        }

        let directory = settingsDirectory(in: currentRoot)
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("settings.plist").path))
        let store = AgentTempStoragePluginLocalStore(settingsDirectory: directory)
        #expect(try store.resolvedRetentionDays() == 7)
    }

    @Test("无版本旧目录存在时合并其内容并仍导入保留天数")
    func mergesUnversionedDirectoryAndStillImports() throws {
        let temp = TempDirectory()
        defer { temp.cleanup() }
        // 无版本旧目录存在并含一个文件。
        let fallbackRoot = temp.url.appendingPathComponent("fallback", isDirectory: true)
        let unversioned = fallbackRoot.appendingPathComponent("AgentTempStorage", isDirectory: true)
        try FileManager.default.createDirectory(at: unversioned, withIntermediateDirectories: true)
        try "legacy".write(to: unversioned.appendingPathComponent("legacy.md"), atomically: true, encoding: .utf8)

        let currentRoot = temp.url.appendingPathComponent("current", isDirectory: true)
        let plugin = AgentTempStoragePlugin()
        try withLegacyFallbackRoot(fallbackRoot) {
            try withLegacyDomain([Self.legacyKey: 14]) {
                try plugin.migrateData(context: makeContext(root: currentRoot))
            }
        }

        let directory = settingsDirectory(in: currentRoot)
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("legacy.md").path))
        let store = AgentTempStoragePluginLocalStore(settingsDirectory: directory)
        #expect(try store.resolvedRetentionDays() == 14)
    }
}