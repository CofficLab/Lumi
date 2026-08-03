import Testing
import Foundation
@testable import MenuBarHelperPlugin

@MainActor
@Test func packageLoads() async throws {
    #expect(MenuBarHelperPlugin().id == "com.coffic.lumi.plugin.menubar-helper")
}

@MainActor
@Test func localStoreReportsSaveResultAndReloadsHiddenItems() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("MenuBarHelperLocalStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = MenuBarManagerPluginLocalStore(settingsDirectory: directory)

    #expect(store.set(["wifi", "clock"], forKey: "MenuBarManager_HiddenItems") == true)

    let reloadedStore = MenuBarManagerPluginLocalStore(settingsDirectory: directory)
    #expect(reloadedStore.array(forKey: "MenuBarManager_HiddenItems") as? [String] == ["wifi", "clock"])
}

@MainActor
@Test func localStoreQuarantinesInvalidSettingsFileAndRecovers() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("MenuBarHelperLocalStore-Invalid-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let settingsURL = directory.appendingPathComponent("settings.plist")
    let corruptURL = directory.appendingPathComponent("settings.corrupt.plist")
    let invalidData = Data("not a plist".utf8)
    try invalidData.write(to: settingsURL)

    let store = MenuBarManagerPluginLocalStore(settingsDirectory: directory)

    #expect(store.set(["wifi"], forKey: "MenuBarManager_HiddenItems") == true)
    #expect((try? Data(contentsOf: corruptURL)) == invalidData)
    #expect(store.array(forKey: "MenuBarManager_HiddenItems") as? [String] == ["wifi"])

    let reloadedStore = MenuBarManagerPluginLocalStore(settingsDirectory: directory)
    #expect(reloadedStore.array(forKey: "MenuBarManager_HiddenItems") as? [String] == ["wifi"])
}

@MainActor
@Test func localStoreReportsFailureWhenSettingsDirectoryIsBlocked() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("MenuBarHelperLocalStore-Blocked-\(UUID().uuidString)", isDirectory: true)
    let blockedDirectory = tempRoot.appendingPathComponent("settings", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    try "not a directory".write(to: blockedDirectory, atomically: true, encoding: .utf8)

    let store = MenuBarManagerPluginLocalStore(settingsDirectory: blockedDirectory)

    #expect(store.set(["wifi"], forKey: "MenuBarManager_HiddenItems") == false)
    #expect(store.array(forKey: "MenuBarManager_HiddenItems") == nil)
}
