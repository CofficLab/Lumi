import Testing
import Foundation
@testable import ThemeStatusBarPlugin

@Test func packageLoads() async throws {
    #expect(ThemeStatusBarPlugin.id == "EditorThemeStatusBar")
}

@Test func localStoreQuarantinesInvalidSettingsFileAndRecovers() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ThemeStatusBarLocalStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let settingsURL = directory.appending(path: "settings.plist")
    let corruptURL = directory.appending(path: "settings.corrupt.plist")
    let invalidData = Data("not a plist".utf8)
    try invalidData.write(to: settingsURL)

    let store = ThemeStatusBarPluginLocalStore(pluginDirectory: directory)

    #expect(store.loadSelectedThemeID() == nil)
    #expect((try? Data(contentsOf: corruptURL)) == invalidData)
    #expect(store.saveSelectedThemeID("lumi-dark") == true)

    let reloadedStore = ThemeStatusBarPluginLocalStore(pluginDirectory: directory)
    #expect(reloadedStore.loadSelectedThemeID() == "lumi-dark")
}

@Test func localStoreReportsFailureWhenPluginDirectoryIsBlocked() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("ThemeStatusBarLocalStore-Blocked-\(UUID().uuidString)", isDirectory: true)
    let blockedDirectory = tempRoot.appending(path: "settings")
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    try "not a directory".write(to: blockedDirectory, atomically: true, encoding: .utf8)

    let store = ThemeStatusBarPluginLocalStore(pluginDirectory: blockedDirectory)

    #expect(store.saveSelectedThemeID("lumi-dark") == false)
    #expect(store.loadSelectedThemeID() == nil)
}
