import KitAgentTool
import Testing
import Foundation
@testable import PluginAgentTempStorage

@MainActor
struct PluginAgentTempStorageTests {
    @Test
    func pluginMetadataIsStable() {
        let plugin = AgentTempStoragePlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.agent-temp-storage")
        #expect(plugin.name.isEmpty == false)
        #expect(plugin.order == 80)
        #expect(plugin.metadata.policy == .alwaysOn)
        #expect(plugin.metadata.category == .system)
        #expect(plugin.metadata.stage == .stable)
    }

    @Test
    func pluginRegistersThreeTools() {
        let names = AgentTempStoragePlugin.agentTools.map(\.name)
        #expect(names == ["list_temp_files", "read_temp_file", "write_temp_file"])
    }

    @Test
    func toolsAreLowRisk() {
        for tool in AgentTempStoragePlugin.agentTools {
            #expect(tool.permissionRiskLevel(arguments: [:]) == .low)
        }
    }

    @Test
    func localizationCatalogIsPackaged() {
        let bundle = Bundle.module
        #expect(bundle.url(forResource: "Localizable", withExtension: "xcstrings") != nil)
        #expect(LumiPluginLocalization.string("Agent Temp Storage", bundle: .module).isEmpty == false)
    }

    @Test
    func storageSupportsNestedReadWriteAndList() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = TempFileStorageService(directory: root, retentionDays: 7)

        let path = try await service.write(filename: "notes/today.md", content: "# today")
        #expect(path.hasSuffix("notes/today.md"))
        #expect(try await service.read(filename: "notes/today.md") == "# today")

        // listFiles is flat: the nested file lives under a directory and is not enumerated.
        let listed = try await service.listFiles()
        #expect(listed.isEmpty)
    }

    @Test
    func storageRejectsInvalidAndTraversingPaths() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = TempFileStorageService(directory: root, retentionDays: 7)

        await #expect(throws: TempFileStorageError.invalidFilename) {
            _ = try await service.write(filename: "", content: "x")
        }
        await #expect(throws: TempFileStorageError.invalidFilename) {
            _ = try await service.write(filename: "   ", content: "x")
        }
        await #expect(throws: TempFileStorageError.invalidFilename) {
            _ = try await service.write(filename: "/absolute.md", content: "x")
        }
        await #expect(throws: TempFileStorageError.pathTraversal) {
            _ = try await service.write(filename: "../escape.md", content: "x")
        }
    }

    @Test
    func readReportsMissingFile() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = TempFileStorageService(directory: root, retentionDays: 7)

        await #expect(throws: TempFileStorageError.fileNotFound("nope.md")) {
            _ = try await service.read(filename: "nope.md")
        }
    }

    @Test
    func listFilesSortsByRecencyAndExcludesDirectories() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = TempFileStorageService(directory: root, retentionDays: 7)

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

        let listed = try await service.listFiles()
        #expect(listed.map(\.name) == ["zebra.md", "alpha.md"])
        #expect(listed.allSatisfy { !$0.name.contains("afolder") })
    }

    @Test
    func purgeRemovesOnlyFilesOlderThanRetention() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let service = TempFileStorageService(directory: root, retentionDays: 7)

        _ = try await service.write(filename: "old.md", content: "old")
        _ = try await service.write(filename: "fresh.md", content: "fresh")
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -40 * 24 * 60 * 60)],
            ofItemAtPath: root.appendingPathComponent("old.md").path
        )

        await service.purgeExpiredFiles()
        let remaining = try await service.listFiles()
        #expect(remaining.map(\.name) == ["fresh.md"])
    }

    @Test
    func storageErrorsExposeDescriptions() {
        #expect(!TempFileStorageError.invalidFilename.errorDescription!.isEmpty)
        #expect(!TempFileStorageError.pathTraversal.errorDescription!.isEmpty)
        #expect(TempFileStorageError.fileNotFound("x").errorDescription?.contains("x") == true)
        #expect(TempFileStorageError.readFailed("boom").errorDescription?.contains("boom") == true)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginAgentTempStorageTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
