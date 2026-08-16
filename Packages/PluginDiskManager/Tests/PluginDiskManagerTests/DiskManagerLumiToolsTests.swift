import Testing
import Foundation
import AgentToolKit
@testable import PluginDiskManager

/// Pure-logic tests for the Disk Manager agent-tool support helpers.
///
/// Tool end-to-end execution touches the live file system, so these tests
/// only cover the deterministic helpers (`formatBytes`, `formatDate`, path
/// resolution) plus a sanity check that the plugin registers the expected tools.
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
}
