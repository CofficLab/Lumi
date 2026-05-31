import Testing
import Foundation
@testable import PluginInput

@Test func packageLoads() async throws {
    #expect(InputPlugin.id == "InputManager")
}

@Test func localStoreReportsSaveResultAndReloadsData() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("InputPluginLocalStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = InputPluginLocalStore(settingsDirectory: directory)
    let data = Data("rule-config".utf8)

    #expect(store.set(data, forKey: "InputPluginConfig") == true)

    let reloadedStore = InputPluginLocalStore(settingsDirectory: directory)
    #expect(reloadedStore.data(forKey: "InputPluginConfig") == data)
}

@Test func localStoreReportsFailureAndPreservesInvalidSettingsFile() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("InputPluginLocalStore-Invalid-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let settingsURL = directory.appendingPathComponent("settings.plist")
    let invalidData = Data("not a plist".utf8)
    try invalidData.write(to: settingsURL)

    let store = InputPluginLocalStore(settingsDirectory: directory)

    #expect(store.set(Data("new config".utf8), forKey: "InputPluginConfig") == false)
    #expect((try? Data(contentsOf: settingsURL)) == invalidData)
    #expect(store.data(forKey: "InputPluginConfig") == nil)
}

@Test func localStoreReportsFailureWhenSettingsDirectoryIsBlocked() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("InputPluginLocalStore-Blocked-\(UUID().uuidString)", isDirectory: true)
    let blockedDirectory = tempRoot.appendingPathComponent("settings", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    try "not a directory".write(to: blockedDirectory, atomically: true, encoding: .utf8)

    let store = InputPluginLocalStore(settingsDirectory: blockedDirectory)

    #expect(store.set(Data("rule-config".utf8), forKey: "InputPluginConfig") == false)
    #expect(store.data(forKey: "InputPluginConfig") == nil)
}

@MainActor
@Test func removeRuleIgnoresStaleOffsets() {
    let viewModel = InputSettingsViewModel()
    viewModel.rules = [
        InputRule(appBundleID: "com.example.one", appName: "One", inputSourceID: "source.one")
    ]

    viewModel.removeRule(at: IndexSet([2]))

    #expect(viewModel.rules.count == 1)
}
