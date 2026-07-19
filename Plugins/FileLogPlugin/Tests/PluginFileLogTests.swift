import Foundation
import Testing
import LumiKernel
@testable import FileLogPlugin

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
        #expect(FileLogPlugin.policy == .alwaysOn)
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

    @Test
    func coordinatorOrdersLogLinesChronologically() {
        let base = Date(timeIntervalSince1970: 1_780_000_000)
        let records = [
            FileLogCoordinator.LogRecord(date: base.addingTimeInterval(2), line: "third\n"),
            FileLogCoordinator.LogRecord(date: base, line: "first\n"),
            FileLogCoordinator.LogRecord(date: base.addingTimeInterval(1), line: "second\n"),
            FileLogCoordinator.LogRecord(date: base.addingTimeInterval(2), line: "fourth\n"),
        ]

        #expect(FileLogCoordinator.orderedLogLines(records) == [
            "first\n",
            "second\n",
            "third\n",
            "fourth\n",
        ])
    }

    @Test
    func coordinatorKeepsRecentLogLinesPending() {
        let base = Date(timeIntervalSince1970: 1_780_000_000)
        let records = [
            FileLogCoordinator.LogRecord(date: base.addingTimeInterval(3), line: "pending\n"),
            FileLogCoordinator.LogRecord(date: base, line: "ready first\n"),
            FileLogCoordinator.LogRecord(date: base.addingTimeInterval(2), line: "ready second\n"),
        ]

        let result = FileLogCoordinator.recordsReadyToWrite(
            records,
            upTo: base.addingTimeInterval(2)
        )

        #expect(result.ready.map(\.line) == [
            "ready first\n",
            "ready second\n",
        ])
        #expect(result.pending.map(\.line) == ["pending\n"])
    }

    @Test
    func coordinatorLogFilenameIncludesProcessID() {
        let date = Calendar.current.date(from: DateComponents(
            year: 2026,
            month: 5,
            day: 16,
            hour: 9,
            minute: 46,
            second: 40
        ))!

        #expect(FileLogCoordinator.logFilename(for: date, processID: 42) == "2026-05-16_09-46-40_pid-42.log")
    }
}

private struct TestFileLogConfiguration: FileLogConfiguration {
    let url: URL

    func logsDirectory() -> URL {
        url
    }
}
