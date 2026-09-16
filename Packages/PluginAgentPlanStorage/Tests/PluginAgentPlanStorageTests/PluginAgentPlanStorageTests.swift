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
        #expect(plugin.metadata.policy == .required)
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

    @Test
    func readAndDeleteReportMissingOrNonFileTargets() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try PlanFileStorageService(directory: root, retentionDays: 30)

        await #expect(throws: PlanFileStorageError.fileNotFound("nope.md")) {
            _ = try await service.read(filename: "nope.md")
        }
        await #expect(throws: PlanFileStorageError.fileNotFound("nope.md")) {
            try await service.delete(filename: "nope.md")
        }

        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("adir"),
            withIntermediateDirectories: false
        )
        await #expect(throws: PlanFileStorageError.notAFile("adir")) {
            _ = try await service.read(filename: "adir")
        }
        await #expect(throws: PlanFileStorageError.notAFile("adir")) {
            try await service.delete(filename: "adir")
        }
    }

    @Test
    func emptyOrWhitespaceFilenamesAreInvalid() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try PlanFileStorageService(directory: root, retentionDays: 30)

        await #expect(throws: PlanFileStorageError.invalidFilename) {
            _ = try await service.write(filename: "", content: "x")
        }
        await #expect(throws: PlanFileStorageError.invalidFilename) {
            _ = try await service.write(filename: "   ", content: "x")
        }

        let path = try await service.write(filename: "  spaced.md  ", content: "trimmed")
        #expect(path.hasSuffix("spaced.md"))
        #expect(try await service.read(filename: "spaced.md") == "trimmed")
    }

    @Test
    func listFilesSortsByRecencyAndExcludesDirectories() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try PlanFileStorageService(directory: root, retentionDays: 30)

        _ = try await service.write(filename: "zebra.md", content: "z")
        _ = try await service.write(filename: "alpha.md", content: "a")
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -60)],
            ofItemAtPath: root.appendingPathComponent("alpha.md").path
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("afolder"),
            withIntermediateDirectories: false
        )

        let listed = await service.listFiles()
        #expect(listed.map(\.name) == ["zebra.md", "alpha.md"])
        #expect(listed.allSatisfy { !$0.name.contains("afolder") })
    }

    @Test
    func retentionClampsToAtLeastOneDay() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try PlanFileStorageService(directory: root, retentionDays: 0)

        _ = try await service.write(filename: "old.md", content: "old")
        _ = try await service.write(filename: "fresh.md", content: "fresh")
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -2 * 24 * 60 * 60)],
            ofItemAtPath: root.appendingPathComponent("old.md").path
        )

        #expect(await service.purgeExpiredFiles() == 1)
        #expect(await service.listFiles().map(\.name) == ["fresh.md"])
    }

    @Test
    func storageErrorsExposeDescriptionsWithContext() {
        #expect(!PlanFileStorageError.invalidFilename.errorDescription!.isEmpty)
        #expect(!PlanFileStorageError.pathTraversal.errorDescription!.isEmpty)
        #expect(PlanFileStorageError.fileNotFound("x").errorDescription?.contains("x") == true)
        #expect(PlanFileStorageError.notAFile("y").errorDescription?.contains("y") == true)
        #expect(PlanFileStorageError.readFailed("boom").errorDescription?.contains("boom") == true)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginAgentPlanStorageTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
