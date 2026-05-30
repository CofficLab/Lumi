import Foundation
import Testing
import LumiCoreKit
@testable import PluginFileLog

struct PluginFileLogTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(FileLogPlugin.id == "FileLog")
        #expect(FileLogPlugin.navigationId == nil)
        #expect(FileLogPlugin.displayName == "File Log")
        #expect(FileLogPlugin.description.isEmpty == false)
        #expect(FileLogPlugin.iconName == "doc.text.below.ecg")
        #expect(FileLogPlugin.isConfigurable == false)
        #expect(FileLogPlugin.category == .system)
        #expect(FileLogPlugin.order == 1)
        #expect(FileLogPlugin.enable == true)
        #expect(FileLogPlugin.shared.instanceLabel == FileLogPlugin.id)
    }

    @Test
    func configurationCanBeInjected() {
        let original = FileLogPlugin.configuration
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("file-log-test")
        FileLogPlugin.configuration = TestFileLogConfiguration(url: tempURL)
        defer { FileLogPlugin.configuration = original }

        #expect(FileLogPlugin.configuration.logsDirectory() == tempURL)
    }

    @Test
    func coordinatorCreatesMissingLogDirectory() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("file-log-test-\(UUID().uuidString)", isDirectory: true)
        let logURL = rootURL.appendingPathComponent("nested/logs", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        #expect(FileManager.default.fileExists(atPath: logURL.path) == false)

        try FileLogCoordinator.prepareLogsDirectory(logURL)

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: logURL.path, isDirectory: &isDirectory)
        #expect(exists)
        #expect(isDirectory.boolValue)
    }
}

private struct TestFileLogConfiguration: FileLogConfiguration {
    let url: URL

    func logsDirectory() -> URL {
        url
    }
}
