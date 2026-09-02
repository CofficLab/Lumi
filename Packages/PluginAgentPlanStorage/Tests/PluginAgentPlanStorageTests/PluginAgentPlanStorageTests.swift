import Foundation
import KitAgentTool
import Testing
@testable import PluginAgentPlanStorage

@MainActor
struct PluginAgentPlanStorageTests {
    @Test
    func pluginMetadataAndToolNamesAreStable() {
        let plugin = AgentPlanStoragePlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.agent-plan-storage")
        #expect(plugin.name == "Agent Plan Storage")
        #expect(plugin.order == 81)
        #expect(plugin.metadata.policy == .enabledByDefault)
        #expect(plugin.metadata.category == .system)
        #expect(AgentPlanStoragePlugin.toolNames == ["write_plan", "read_plan", "list_plans", "delete_plan"])
    }

    @Test
    func storageSupportsNestedReadWriteListAndDelete() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try PlanFileStorageService(directory: root, retentionDays: 30)

        let path = try await service.write(filename: "work/current.md", content: "# Current plan")
        #expect(path.hasSuffix("/work/current.md"))
        #expect(try await service.read(filename: "work/current.md") == "# Current plan")
        let listedFiles = await service.listFiles()
        #expect(listedFiles.map(\.name) == ["work/current.md"])

        try await service.delete(filename: "work/current.md")
        #expect(await service.listFiles().isEmpty)
    }

    @Test
    func storageRejectsTraversalAndAbsolutePaths() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try PlanFileStorageService(directory: root, retentionDays: 30)

        await #expect(throws: PlanFileStorageError.pathTraversal) {
            _ = try await service.write(filename: "../outside.md", content: "no")
        }
        await #expect(throws: PlanFileStorageError.invalidFilename) {
            _ = try await service.write(filename: "/outside.md", content: "no")
        }
    }

    @Test
    func cleanupRemovesOnlyFilesOlderThanRetention() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try PlanFileStorageService(directory: root, retentionDays: 30)
        let oldDate = Date(timeIntervalSince1970: 1_700_000_000)
        let now = oldDate.addingTimeInterval(31 * 24 * 60 * 60)

        _ = try await service.write(filename: "old.md", content: "old")
        _ = try await service.write(filename: "new.md", content: "new")
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: root.appendingPathComponent("old.md").path)

        #expect(await service.purgeExpiredFiles(now: now) == 1)
        #expect(await service.listFiles().map(\.name) == ["new.md"])
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginAgentPlanStorageTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
