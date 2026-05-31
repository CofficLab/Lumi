import Testing
import Foundation
@testable import PluginRClick

@Test func packageLoads() async throws {
    #expect(RClickPlugin.id == "RClick")
}

@Test func appGroupConfigURLUsesSharedJSONFilename() {
    let containerURL = URL(fileURLWithPath: "/tmp/lumi-group", isDirectory: true)

    #expect(
        RClickConfigManager.sharedConfigURL(in: containerURL).path
            == "/tmp/lumi-group/RClickConfig.json"
    )
}

@MainActor
@Test func appGroupConfigQuarantinesInvalidJSONAndRecoversFromLegacyBackup() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("RClickConfigManager-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let appGroupConfigURL = directory.appending(path: RClickConfigManager.sharedConfigFilename)
    let corruptURL = RClickConfigManager.corruptSharedConfigURL(for: appGroupConfigURL)
    let invalidData = Data("not json".utf8)
    try invalidData.write(to: appGroupConfigURL)

    let store = RClickPluginLocalStore(pluginDirectory: directory.appending(path: "LocalStore"))
    let backupConfig = RClickConfig(
        items: [RClickMenuItem(id: "copy", type: .copyPath, customTitle: "Copy Absolute Path")],
        fileTemplates: [NewFileTemplate(id: "swift", name: "Swift", extensionName: "swift")]
    )
    let backupData = try JSONEncoder().encode(backupConfig)
    #expect(store.set(backupData, forKey: "rClickConfig") == true)

    let manager = RClickConfigManager(appGroupConfigFileURL: appGroupConfigURL, store: store)

    #expect(manager.config == backupConfig)
    #expect((try? Data(contentsOf: corruptURL)) == invalidData)
    #expect((try? JSONDecoder().decode(RClickConfig.self, from: Data(contentsOf: appGroupConfigURL))) == backupConfig)
}

@MainActor
@Test func appGroupConfigQuarantinesInvalidJSONBeforeWritingDefault() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("RClickConfigManager-Default-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let appGroupConfigURL = directory.appending(path: RClickConfigManager.sharedConfigFilename)
    let corruptURL = RClickConfigManager.corruptSharedConfigURL(for: appGroupConfigURL)
    let invalidData = Data("not json".utf8)
    try invalidData.write(to: appGroupConfigURL)

    let store = RClickPluginLocalStore(pluginDirectory: directory.appending(path: "LocalStore"))
    let manager = RClickConfigManager(appGroupConfigFileURL: appGroupConfigURL, store: store)

    #expect(manager.config == .default)
    #expect((try? Data(contentsOf: corruptURL)) == invalidData)
    #expect((try? JSONDecoder().decode(RClickConfig.self, from: Data(contentsOf: appGroupConfigURL))) == .default)
}

@Test func localStoreQuarantinesInvalidSettingsFileAndRecovers() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("RClickLocalStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let settingsURL = directory.appending(path: "settings.plist")
    let corruptURL = directory.appending(path: "settings.corrupt.plist")
    let invalidData = Data("not a plist".utf8)
    try invalidData.write(to: settingsURL)

    let store = RClickPluginLocalStore(pluginDirectory: directory)

    #expect(store.string(forKey: "name") == nil)
    #expect((try? Data(contentsOf: corruptURL)) == invalidData)
    #expect(store.set("Context Menu", forKey: "name") == true)

    let reloadedStore = RClickPluginLocalStore(pluginDirectory: directory)
    #expect(reloadedStore.string(forKey: "name") == "Context Menu")
}

@Test func localStoreReportsFailureWhenPluginDirectoryIsBlocked() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("RClickLocalStore-Blocked-\(UUID().uuidString)", isDirectory: true)
    let blockedDirectory = tempRoot.appending(path: "settings")
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    try "not a directory".write(to: blockedDirectory, atomically: true, encoding: .utf8)

    let store = RClickPluginLocalStore(pluginDirectory: blockedDirectory)

    #expect(store.set("Context Menu", forKey: "name") == false)
    #expect(store.string(forKey: "name") == nil)
}
