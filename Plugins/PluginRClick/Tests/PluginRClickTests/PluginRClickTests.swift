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
