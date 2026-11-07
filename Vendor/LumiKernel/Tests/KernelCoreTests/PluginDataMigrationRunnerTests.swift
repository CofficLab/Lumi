import Foundation
import Testing
@testable import KernelCore

@Suite("KernelCore Plugin Data Migration")
@MainActor
struct PluginDataMigrationRunnerTests {
    @Test("runner passes the shared migration context to migrating plugins")
    func runnerPassesContext() throws {
        let currentRoot = temporaryDirectory(named: "current")
        let legacyRoot = temporaryDirectory(named: "legacy")
        defer {
            try? FileManager.default.removeItem(at: currentRoot)
            try? FileManager.default.removeItem(at: legacyRoot)
        }

        let plugin = MigratingPlugin(id: "plugin.test")
        let runner = PluginDataMigrationRunner(
            currentMajorVersion: 4,
            currentDataRootDirectory: currentRoot,
            legacyDataRootDirectories: [0: legacyRoot]
        )

        try runner.run(for: [plugin])

        #expect(plugin.migrationContext?.pluginID == "plugin.test")
        #expect(plugin.migrationContext?.currentMajorVersion == 4)
        #expect(plugin.migrationContext?.currentDataRootDirectory == currentRoot.standardizedFileURL)
        #expect(plugin.migrationContext?.legacyDataRootDirectories[0] == legacyRoot.standardizedFileURL)
    }

    @Test("runner ignores plugins without migration support")
    func runnerSkipsNonMigratingPlugins() throws {
        let currentRoot = temporaryDirectory(named: "current")
        defer { try? FileManager.default.removeItem(at: currentRoot) }

        try PluginDataMigrationRunner(
            currentMajorVersion: 1,
            currentDataRootDirectory: currentRoot
        )
            .run(for: [RegularPlugin(id: "plugin.regular")])
    }

    private func temporaryDirectory(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("KernelRunner-(name)-(UUID().uuidString)", isDirectory: true)
    }

    @MainActor
    private final class MigratingPlugin: PluginDataMigrating {
        let id: String
        let metadata: PluginMetadata
        var migrationContext: PluginDataMigrationContext?

        init(id: String) {
            self.id = id
            self.metadata = PluginMetadata(id: id)
        }

        func onBoot(kernel: KernelCoreContainer) throws {}

        func migrateData(context: PluginDataMigrationContext) throws {
            migrationContext = context
        }
    }

    @MainActor
    private final class RegularPlugin: SuperPlugin {
        let id: String
        let metadata: PluginMetadata

        init(id: String) {
            self.id = id
            self.metadata = PluginMetadata(id: id)
        }
    }
}
