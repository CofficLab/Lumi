import Testing
import Foundation
import KitAgentTool
@testable import PluginDiskManager

/// Deterministic tests for the Disk Manager agent-tool support helpers.
@Suite struct DiskManagerToolSupportTests {

    @Test func formatBytesProducesHumanReadableString() {
        let result = DiskManagerToolSupport.formatBytes(1_500_000) // ~1.5 MB
        #expect(result.contains("MB") || result.contains("KB"))
    }

    @Test func formatBytesHandlesZero() {
        #expect(DiskManagerToolSupport.formatBytes(0).isEmpty == false)
    }

    @Test func formatDateReturnsUnknownForNil() {
        #expect(DiskManagerToolSupport.formatDate(nil) == "unknown")
    }

    @Test func formatDateProducesISO8601ForConcreteDate() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let result = DiskManagerToolSupport.formatDate(date)
        // ISO8601DateFormatter with .withFullDate yields a YYYY-MM-DD string.
        #expect(result.count >= 10)
        #expect(result.first == "2")
    }

    @Test func resolveScanPathFallsBackToHomeWhenEmpty() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        #expect(DiskManagerToolSupport.resolveScanPath(nil) == home)
        #expect(DiskManagerToolSupport.resolveScanPath("") == home)
        #expect(DiskManagerToolSupport.resolveScanPath("   ") == home)
    }

    @Test func resolveScanPathExpandsTilde() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        #expect(DiskManagerToolSupport.resolveScanPath("~") == home)
        #expect(DiskManagerToolSupport.resolveScanPath("~/Downloads") == "\(home)/Downloads")
    }

    @Test func resolveScanPathAnchorsRelativePathsToHome() {
        let home = URL(fileURLWithPath: FileManager.default.homeDirectoryForCurrentUser.path)
        let documents = home.appendingPathComponent("Documents").path

        #expect(DiskManagerToolSupport.resolveScanPath("Documents") == documents)
        #expect(DiskManagerToolSupport.resolveScanPath("  Documents  ") == documents)
        #expect(
            DiskManagerToolSupport.resolveScanPath("Documents/Invoices")
                == home.appendingPathComponent("Documents").appendingPathComponent("Invoices").path
        )
        // 绝对路径保持原样。
        #expect(DiskManagerToolSupport.resolveScanPath("/tmp") == "/tmp")
    }
}

@Suite(.serialized)
struct DirectoryTreeServiceTests {

    @Test func topLevelScanAggregatesNestedUsageWithoutMaterializingTree() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let nested = root.appendingPathComponent("Applications/Nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 11).write(to: nested.appendingPathComponent("one.bin"))
        try Data(repeating: 2, count: 23).write(to: root.appendingPathComponent("Downloads.bin"))
        try Data(repeating: 3, count: 7).write(to: root.appendingPathComponent("root.bin"))

        let progress = ProgressRecorder()
        let entries = try await DirectoryTreeService().scanTopLevelDirectoryUsage(
            atPath: root.path,
            maxDuration: 10,
            onProgress: { value in await progress.record(value) }
        )

        let byName = Dictionary(uniqueKeysWithValues: entries.map { ($0.name, $0) })
        #expect(byName["Applications"]?.isDirectory == true)
        #expect(byName["Applications"]?.size == 11)
        #expect(byName["Downloads.bin"]?.size == 23)
        #expect(byName["root.bin"]?.size == 7)
        #expect(await progress.count >= 2)
    }

    @Test func topLevelScanStopsAtEntryBudget() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try Data(repeating: 1, count: 1).write(to: root.appendingPathComponent("file-a.bin"))
        try Data(repeating: 2, count: 1).write(to: root.appendingPathComponent("file-b.bin"))

        do {
            _ = try await DirectoryTreeService().scanTopLevelDirectoryUsage(
                atPath: root.path,
                maxEntries: 1,
                maxDuration: 10
            )
            Issue.record("Expected the scan to stop at the configured entry budget")
        } catch let error as DirectoryTreeScanError {
            guard case .budgetExceeded = error else {
                Issue.record("Unexpected scan error: \(error)")
                return
            }
        }
    }

    @Test func missingScanRootThrowsRootUnavailable() async {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-missing-tree-\(UUID().uuidString)", isDirectory: true)

        do {
            _ = try await DirectoryTreeService().scanTopLevelDirectoryUsage(atPath: missing.path)
            Issue.record("Expected a missing scan root to throw")
        } catch let error as DiskManagerScanError {
            guard case .rootUnavailable(_, let reason) = error else {
                Issue.record("Unexpected scan error: \(error)")
                return
            }
            #expect(reason == "the path does not exist")
            #expect(error.localizedDescription.contains(missing.lastPathComponent))
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func emptyScanRootReturnsEmptyResult() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let entries = try await DirectoryTreeService().scanTopLevelDirectoryUsage(atPath: root.path)
        #expect(entries.isEmpty)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-directory-scan-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}

private actor ProgressRecorder {
    private(set) var values: [ScanProgress] = []

    func record(_ value: ScanProgress) {
        values.append(value)
    }

    var count: Int { values.count }
}

@Suite(.serialized)
struct LargeFilesServiceTests {

    @Test func largeFileScanThrowsForMissingRoot() async {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-missing-large-files-\(UUID().uuidString)", isDirectory: true)

        do {
            _ = try await LargeFilesService.shared.scanLargeFiles(atPath: missing.path)
            Issue.record("Expected a missing scan root to throw")
        } catch let error as DiskManagerScanError {
            guard case .rootUnavailable(_, let reason) = error else {
                Issue.record("Unexpected scan error: \(error)")
                return
            }
            #expect(reason == "the path does not exist")
            #expect(error.localizedDescription.contains(missing.lastPathComponent))
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func largeFileScanReturnsEmptyForExistingEmptyRoot() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-empty-large-files-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let files = try await LargeFilesService.shared.scanLargeFiles(atPath: root.path)
        #expect(files.isEmpty)
    }
}

@MainActor
@Suite struct DiskManagerAgentToolsTests {

    private var toolNames: Set<String> {
        Set(DiskManagerPlugin.agentTools.map { $0.name })
    }

    @Test func pluginRegistersAllDiskManagerTools() {
        let expected: Set<String> = [
            "disk-manager.disk-usage",
            "disk-manager.scan-large-files",
            "disk-manager.scan-directory-tree",
            "disk-manager.scan-caches",
            "disk-manager.clean-caches",
            "disk-manager.scan-xcode-caches",
            "disk-manager.clean-xcode-caches",
            "disk-manager.scan-projects",
            "disk-manager.clean-projects",
            "disk-manager.delete-files",
        ]
        #expect(toolNames == expected)
    }

    @Test func destructiveToolsAreHighRisk() {
        let destructiveIDs: Set<String> = [
            "disk-manager.clean-caches",
            "disk-manager.clean-xcode-caches",
            "disk-manager.clean-projects",
            "disk-manager.delete-files",
        ]
        for tool in DiskManagerPlugin.agentTools where destructiveIDs.contains(tool.name) {
            #expect(tool.permissionRiskLevel(arguments: [:]) == .high)
        }
    }

    @Test func readToolsAreLowRisk() {
        let readIDs: Set<String> = [
            "disk-manager.disk-usage",
            "disk-manager.scan-large-files",
            "disk-manager.scan-directory-tree",
            "disk-manager.scan-caches",
            "disk-manager.scan-xcode-caches",
            "disk-manager.scan-projects",
        ]
        for tool in DiskManagerPlugin.agentTools where readIDs.contains(tool.name) {
            #expect(tool.permissionRiskLevel(arguments: [:]) == .low)
        }
    }

    @Test func destructiveToolsProvideDisplayDescriptions() {
        let paths = ["paths": ToolArgument(["/tmp/a", "/tmp/b"])]
        for tool in DiskManagerPlugin.agentTools where tool.name == "disk-manager.delete-files" {
            let description = tool.displayDescription(for: paths)
            #expect(description.contains("2"))
        }
    }

    @Test func scanLargeFilesToolReportsMissingRootAsFailure() async throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-missing-tool-large-\(UUID().uuidString)", isDirectory: true)

        let output = try await ScanLargeFilesTool().execute(arguments: ["path": ToolArgument(missing.path)])

        #expect(output.contains("Failed to scan large files"))
        #expect(!output.contains("No files larger than 50 MB were found"))
    }

    @Test func scanDirectoryTreeToolReportsMissingRootAsFailure() async throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-missing-tool-tree-\(UUID().uuidString)", isDirectory: true)

        let output = try await ScanDirectoryTreeTool().execute(arguments: ["path": ToolArgument(missing.path)])

        #expect(output.contains("Failed to analyze directory tree"))
        #expect(!output.contains("No entries were found"))
    }
}
