import Foundation
import Testing
@testable import PluginFileLog

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
