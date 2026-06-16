import Foundation
@testable import LumiCoreKit
import Testing

@Test func appConfigUsesConfiguredDataRootDirectory() async throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("AppConfigTests-\(UUID().uuidString)", isDirectory: true)
    let dataRoot = tempRoot.appendingPathComponent("db_debug_v4", isDirectory: true)
    try FileManager.default.createDirectory(at: dataRoot, withIntermediateDirectories: true)
    defer {
        AppConfig.resetForTesting()
        try? FileManager.default.removeItem(at: tempRoot)
    }

    await MainActor.run {
        AppConfig.configure(dataRootDirectory: dataRoot)
    }

    #expect(AppConfig.getDBFolderURL() == dataRoot.standardizedFileURL)

    let pluginDirectory = AppConfig.getPluginDBFolderURL(pluginName: "Memory")
    #expect(pluginDirectory.lastPathComponent == "Memory")
    #expect(pluginDirectory.deletingLastPathComponent().lastPathComponent == "db_debug_v4")
}

@Test func storageMigrationMovesMisplacedPluginDirectoriesIntoDataRoot() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("LumiStorageMigrationTests-\(UUID().uuidString)", isDirectory: true)
    let appDirectory = tempRoot.appendingPathComponent("com.coffic.lumi", isDirectory: true)
    let dataRoot = appDirectory.appendingPathComponent("db_debug_v4", isDirectory: true)
    let misplacedPlugin = appDirectory.appendingPathComponent("LayoutPlugin", isDirectory: true)
    let marker = misplacedPlugin.appendingPathComponent("settings.plist")

    try FileManager.default.createDirectory(at: misplacedPlugin, withIntermediateDirectories: true)
    try Data("{}".utf8).write(to: marker)
    try FileManager.default.createDirectory(at: dataRoot, withIntermediateDirectories: true)

    LumiStorageMigration.migrateMisplacedPluginDirectories(to: dataRoot)

    #expect(!FileManager.default.fileExists(atPath: misplacedPlugin.path))
    #expect(FileManager.default.fileExists(atPath: dataRoot.appendingPathComponent("LayoutPlugin/settings.plist").path))
}

@Test func storageMigrationSkipsVersionedDatabaseDirectories() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("LumiStorageMigrationSkipTests-\(UUID().uuidString)", isDirectory: true)
    let appDirectory = tempRoot.appendingPathComponent("com.coffic.lumi", isDirectory: true)
    let dataRoot = appDirectory.appendingPathComponent("db_debug_v4", isDirectory: true)
    let oldDatabase = appDirectory.appendingPathComponent("db_debug_v3", isDirectory: true)

    try FileManager.default.createDirectory(at: oldDatabase, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: dataRoot, withIntermediateDirectories: true)

    LumiStorageMigration.migrateMisplacedPluginDirectories(to: dataRoot)

    #expect(FileManager.default.fileExists(atPath: oldDatabase.path))
}
