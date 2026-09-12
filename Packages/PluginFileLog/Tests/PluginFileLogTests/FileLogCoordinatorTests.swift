import Foundation
import KernelCore
import ProviderDiagnostics
import ProviderStorage
import Testing
@testable import PluginFileLog


@Suite(.serialized)
struct FileLogCoordinatorTests {
    @Test func preparesLogDirectory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginFileLogTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        try FileLogCoordinator.prepareLogsDirectory(directory)
        #expect(FileManager.default.fileExists(atPath: directory.path))
    }

    @Test func matchesLumiAndKitLLMSubsystems() {
        let predicate = FileLogCoordinator.subsystemPredicate(for: "com.coffic.lumi")

        #expect(predicate.evaluate(with: ["subsystem": "com.coffic.lumi"]))
        #expect(predicate.evaluate(with: ["subsystem": "com.coffic.lumi.plugin.message-list"]))
        #expect(predicate.evaluate(with: ["subsystem": "com.kit.llm"]))
        #expect(predicate.evaluate(with: ["subsystem": "com.kit.llm.network"]))
        #expect(!predicate.evaluate(with: ["subsystem": "com.example.other"]))
        #expect(!predicate.evaluate(with: ["subsystem": "com.coffic.luminescence"]))

        let customPredicate = FileLogCoordinator.subsystemPredicate(for: "org.example.product")
        #expect(customPredicate.evaluate(with: ["subsystem": "org.example.product.plugin"])
            == true)
        #expect(customPredicate.evaluate(with: ["subsystem": "com.kit.llm.network"]))
        #expect(!customPredicate.evaluate(with: ["subsystem": "org.example.productsibling"]))
    }

    @Test func recordsReadyToWriteAreChronologicalStableAndRespectCutoff() {
        let cutoff = Date(timeIntervalSince1970: 20)
        let records = [
            FileLogCoordinator.LogRecord(date: Date(timeIntervalSince1970: 30), key: "late", line: "late"),
            FileLogCoordinator.LogRecord(date: Date(timeIntervalSince1970: 10), key: "early", line: "early"),
            FileLogCoordinator.LogRecord(date: cutoff, key: "equal-a", line: "equal-a"),
            FileLogCoordinator.LogRecord(date: cutoff, key: "equal-b", line: "equal-b"),
        ]

        let result = FileLogCoordinator.recordsReadyToWrite(records, upTo: cutoff)
        #expect(result.ready.map(\.line) == ["early", "equal-a", "equal-b"])
        #expect(result.pending.map(\.line) == ["late"])
    }

    @Test func startAndStopCreateACompleteHeaderLog() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginFileLogLifecycleTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = FileLogCoordinator(logsDirectory: directory, pollInterval: 60)

        coordinator.start()
        coordinator.stopAndWait()

        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension == "log" }
        let logFile = try #require(files.first)
        let contents = try String(contentsOf: logFile, encoding: .utf8)
        #if DEBUG
        let environment = "Debug"
        #else
        let environment = "Production"
        #endif
        #expect(contents.contains("=== Lumi Log ==="))
        #expect(contents.contains("Environment: \(environment)"))
        #expect(contents.contains("Database Version: v"))
        #expect(files.count == 1)
    }

    @Test func startupPurgesOldestLogsUntilDirectoryIsWithinItsLimit() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginFileLogRetentionTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let oldest = directory.appendingPathComponent("oldest.log")
        let newest = directory.appendingPathComponent("newest.log")
        try Data(repeating: 1, count: 7).write(to: oldest)
        try Data(repeating: 2, count: 7).write(to: newest)
        try FileManager.default.setAttributes(
            [.creationDate: Date().addingTimeInterval(-60)],
            ofItemAtPath: oldest.path
        )
        try FileManager.default.setAttributes([.creationDate: Date()], ofItemAtPath: newest.path)

        let coordinator = FileLogCoordinator(
            logsDirectory: directory,
            maxDirectorySize: 10,
            pollInterval: 60
        )
        coordinator.start()
        coordinator.stopAndWait()

        #expect(!FileManager.default.fileExists(atPath: oldest.path))
        #expect(FileManager.default.fileExists(atPath: newest.path))
    }

    @Test func migratesLegacyLogsIntoPluginIDDirectory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginFileLogMigrationTests-\(UUID().uuidString)", isDirectory: true)
        let legacyDirectory = root.appendingPathComponent("FileLog", isDirectory: true)
        let currentDirectory = root.appendingPathComponent(FileLogPlugin.pluginID, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: legacyDirectory, withIntermediateDirectories: true)
        let legacyFile = legacyDirectory.appendingPathComponent("2026-01-01.log")
        try Data("legacy".utf8).write(to: legacyFile)

        try FileLogCoordinator.migrateLegacyDirectory(from: legacyDirectory, to: currentDirectory)

        #expect(FileManager.default.fileExists(atPath: currentDirectory.appendingPathComponent("2026-01-01.log").path))
        #expect(!FileManager.default.fileExists(atPath: legacyDirectory.path))
    }

    @Test func migrationPreservesCollisionsAndLeavesNonLogFilesAlone() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginFileLogCollisionTests-\(UUID().uuidString)", isDirectory: true)
        let legacyDirectory = root.appendingPathComponent("FileLog", isDirectory: true)
        let currentDirectory = root.appendingPathComponent(FileLogPlugin.pluginID, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: legacyDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: currentDirectory, withIntermediateDirectories: true)
        try Data("old log".utf8).write(to: legacyDirectory.appendingPathComponent("shared.log"))
        try Data("new log".utf8).write(to: currentDirectory.appendingPathComponent("shared.log"))
        try Data("keep me".utf8).write(to: legacyDirectory.appendingPathComponent("notes.txt"))

        try FileLogCoordinator.migrateLegacyDirectory(from: legacyDirectory, to: currentDirectory)

        let currentFiles = try FileManager.default.contentsOfDirectory(at: currentDirectory, includingPropertiesForKeys: nil)
        #expect(currentFiles.filter { $0.pathExtension == "log" }.count == 2)
        #expect(try String(contentsOf: currentDirectory.appendingPathComponent("shared.log"), encoding: .utf8) == "new log")
        let preservedLegacyLog = try #require(currentFiles.first { $0.lastPathComponent.hasPrefix("shared-legacy-") })
        #expect(try String(contentsOf: preservedLegacyLog, encoding: .utf8) == "old log")
        #expect(try String(contentsOf: legacyDirectory.appendingPathComponent("notes.txt"), encoding: .utf8) == "keep me")
        #expect(FileManager.default.fileExists(atPath: legacyDirectory.path))
    }

    @Test func migrationSkipsMissingOrIdenticalDirectoriesAndRemovesAnEmptyLegacyDirectory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginFileLogEmptyMigrationTests-\(UUID().uuidString)", isDirectory: true)
        let missingDirectory = root.appendingPathComponent("missing", isDirectory: true)
        let currentDirectory = root.appendingPathComponent("current", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileLogCoordinator.migrateLegacyDirectory(from: missingDirectory, to: currentDirectory)
        #expect(!FileManager.default.fileExists(atPath: currentDirectory.path))

        try FileManager.default.createDirectory(at: currentDirectory, withIntermediateDirectories: true)
        try FileLogCoordinator.migrateLegacyDirectory(from: currentDirectory, to: currentDirectory)
        #expect(FileManager.default.fileExists(atPath: currentDirectory.path))

        let emptyLegacyDirectory = root.appendingPathComponent("empty-legacy", isDirectory: true)
        try FileManager.default.createDirectory(at: emptyLegacyDirectory, withIntermediateDirectories: true)
        try FileLogCoordinator.migrateLegacyDirectory(from: emptyLegacyDirectory, to: currentDirectory)
        #expect(!FileManager.default.fileExists(atPath: emptyLegacyDirectory.path))
    }

    @Test func createsDiagnosticsArchiveWithLogAndManifest() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginFileLogArchiveTests-\(UUID().uuidString)", isDirectory: true)
        let logsDirectory = root.appendingPathComponent("logs", isDirectory: true)
        let extractionDirectory = root.appendingPathComponent("extracted", isDirectory: true)
        var archiveURL: URL?
        defer {
            if let archiveURL { try? FileManager.default.removeItem(at: archiveURL) }
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        try Data("diagnostic entry\n".utf8).write(to: logsDirectory.appendingPathComponent("sample.log"))

        let archive = try await FileLogCoordinator(logsDirectory: logsDirectory).makeDiagnosticsArchive()
        archiveURL = archive.url
        #expect(archive.filename.hasPrefix("Lumi-Diagnostics-"))
        #expect(FileManager.default.fileExists(atPath: archive.url.path))

        try FileManager.default.createDirectory(at: extractionDirectory, withIntermediateDirectories: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archive.url.path, extractionDirectory.path]
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)

        let extractedFiles = try FileManager.default.contentsOfDirectory(
            at: extractionDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        let archiveRoot = try #require(extractedFiles.first)
        let stagedDirectory = archiveRoot.appendingPathComponent("logs", isDirectory: true)
        #expect(try String(contentsOf: stagedDirectory.appendingPathComponent("sample.log"), encoding: .utf8) == "diagnostic entry\n")

        let manifestData = try Data(contentsOf: archiveRoot.appendingPathComponent("manifest.json"))
        let manifest = try #require(JSONSerialization.jsonObject(with: manifestData) as? [String: Any])
        #expect(manifest["logFileCount"] as? Int == 1)
        #expect(manifest["architecture"] as? String == "arm64")
    }

    @MainActor
    @Test func pluginMigratesLogsRegistersDiagnosticsAndStops() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginFileLogLifecycleTests-\(UUID().uuidString)", isDirectory: true)
        let storage = FileLogTestStorageProvider(root: root)
        let currentDirectory = storage.pluginDataDirectory(for: FileLogPlugin.pluginID)
        let legacyDirectory = root.appendingPathComponent("FileLog", isDirectory: true)
        let kernel = KernelCoreContainer()
        let previousDirectory = FileLogRuntimeBridge.logsDirectory
        defer {
            FileLogCoordinator.shared.stopAndWait()
            FileLogRuntimeBridge.logsDirectory = previousDirectory
            try? FileManager.default.removeItem(at: root)
        }

        try FileManager.default.createDirectory(at: legacyDirectory, withIntermediateDirectories: true)
        try Data("legacy entry\n".utf8).write(to: legacyDirectory.appendingPathComponent("legacy.log"))
        try kernel.registerProvider((any StorageProviding).self, storage)

        let plugin = FileLogPlugin()
        try plugin.onBoot(kernel: kernel)
        #expect(FileLogRuntimeBridge.logsDirectory == currentDirectory)
        #expect(FileManager.default.fileExists(atPath: currentDirectory.appendingPathComponent("legacy.log").path))
        #expect(!FileManager.default.fileExists(atPath: legacyDirectory.path))
        #expect(kernel.resolveProvider((any DiagnosticsProviding).self) === FileLogCoordinator.shared)

        try plugin.onShutdown(kernel: kernel)
        FileLogCoordinator.shared.stopAndWait()
        let filenames = try FileManager.default.contentsOfDirectory(atPath: currentDirectory.path)
        #expect(filenames.contains { $0.hasSuffix(".log") })
    }

    @MainActor
    @Test func pluginBootWithoutStorageUsesFallbackAndCanShutDown() throws {
        let plugin = FileLogPlugin()
        let kernel = KernelCoreContainer()
        let previousDirectory = FileLogRuntimeBridge.logsDirectory
        let testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PluginFileLogFallbackTests-\(UUID().uuidString)", isDirectory: true)
        FileLogRuntimeBridge.logsDirectory = testDirectory
        defer {
            FileLogCoordinator.shared.stopAndWait()
            FileLogRuntimeBridge.logsDirectory = previousDirectory
            try? FileManager.default.removeItem(at: testDirectory)
        }

        try plugin.onBoot(kernel: kernel)
        #expect(kernel.resolveProvider((any DiagnosticsProviding).self) === FileLogCoordinator.shared)
        try plugin.onShutdown(kernel: kernel)
        FileLogCoordinator.shared.stopAndWait()
    }

    @MainActor
    private final class FileLogTestStorageProvider: StorageProviding {
        let dataRootDirectory: URL

        init(root: URL) {
            dataRootDirectory = root
        }

        func pluginDataDirectory(for pluginID: String) -> URL {
            dataRootDirectory.appendingPathComponent(pluginID, isDirectory: true)
        }

        func coreDataDirectory() -> URL {
            dataRootDirectory.appendingPathComponent("core", isDirectory: true)
        }
    }
}
