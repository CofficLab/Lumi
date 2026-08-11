import Testing
import Foundation
import LumiKernel
@testable import DiskManagerPlugin

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

    @MainActor
    @Test func resolveScanPathFallsBackToHomeWhenEmpty() {
        let kernel = LumiKernel()
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        #expect(DiskManagerToolSupport.resolveScanPath(nil, kernel: kernel) == home)
        #expect(DiskManagerToolSupport.resolveScanPath("", kernel: kernel) == home)
        #expect(DiskManagerToolSupport.resolveScanPath("   ", kernel: kernel) == home)
    }

    @MainActor
    @Test func resolveScanPathExpandsTilde() {
        let kernel = LumiKernel()
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        #expect(DiskManagerToolSupport.resolveScanPath("~", kernel: kernel) == home)
        #expect(DiskManagerToolSupport.resolveScanPath("~/Downloads", kernel: kernel) == "\(home)/Downloads")
    }
}

@MainActor
@Suite struct DiskManagerAgentToolsTests {

    @Test func pluginRegistersAllDiskManagerTools() {
        let plugin = DiskManagerPlugin()
        let kernel = LumiKernel()
        let ids = Set(plugin.agentTools(kernel: kernel).map { $0.name })
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
        #expect(ids == expected)
    }

    @Test func destructiveToolsAreHighRisk() {
        let plugin = DiskManagerPlugin()
        let kernel = LumiKernel()
        let destructiveIDs: Set<String> = [
            "disk-manager.clean-caches",
            "disk-manager.clean-xcode-caches",
            "disk-manager.clean-projects",
            "disk-manager.delete-files",
        ]
        for tool in plugin.agentTools(kernel: kernel) where destructiveIDs.contains(tool.name) {
            #expect(tool.riskLevel(arguments: [:], kernel: kernel) == .high)
            #expect(tool.tags.contains(.destructive))
        }
    }

    @Test func readToolsAreLowRiskAndReadOnly() {
        let plugin = DiskManagerPlugin()
        let kernel = LumiKernel()
        let readIDs: Set<String> = [
            "disk-manager.disk-usage",
            "disk-manager.scan-large-files",
            "disk-manager.scan-directory-tree",
            "disk-manager.scan-caches",
            "disk-manager.scan-xcode-caches",
            "disk-manager.scan-projects",
        ]
        for tool in plugin.agentTools(kernel: kernel) where readIDs.contains(tool.name) {
            #expect(tool.riskLevel(arguments: [:], kernel: kernel) == .low)
            #expect(tool.tags.contains(.readOnly))
        }
    }
}
