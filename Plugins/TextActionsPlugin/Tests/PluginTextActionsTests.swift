import Testing
import ApplicationServices
import Foundation
@testable import TextActionsPlugin

@Test func packageLoads() async throws {
    #expect(TextActionsPlugin.id == "TextActions")
    #expect(TextActionsPlugin.navigationId == "text_actions")
    #expect(TextActionsPlugin.displayName.isEmpty == false)
    #expect(TextActionsPlugin.iconName == "text.cursor")
    #expect(TextActionsPlugin.category == .editor)
}

@Test func axElementCastRejectsNonAccessibilityObjects() {
    let object = "not an accessibility element" as CFString

    #expect(TextSelectionManager.axElement(from: object) == nil)
}

@Test func axElementCastAcceptsAccessibilityElements() {
    let element = AXUIElementCreateSystemWide()

    #expect(TextSelectionManager.axElement(from: element) != nil)
}

@Test func localStoreSavesAndReloadsSettings() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("TextActionsLocalStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = TextActionsPluginLocalStore(settingsDirectory: directory)

    #expect(store.set(true, forKey: "TextActionsEnabled") == true)

    let reloadedStore = TextActionsPluginLocalStore(settingsDirectory: directory)
    #expect(reloadedStore.object(forKey: "TextActionsEnabled") as? Bool == true)
}

@Test func localStoreQuarantinesInvalidSettingsFileAndRecovers() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("TextActionsLocalStore-Invalid-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let settingsURL = directory.appendingPathComponent("settings.plist")
    let corruptURL = directory.appendingPathComponent("settings.corrupt.plist")
    let invalidData = Data("not a plist".utf8)
    try invalidData.write(to: settingsURL)

    let store = TextActionsPluginLocalStore(settingsDirectory: directory)

    #expect(store.set(true, forKey: "TextActionsEnabled") == true)
    #expect((try? Data(contentsOf: corruptURL)) == invalidData)
    #expect(store.object(forKey: "TextActionsEnabled") as? Bool == true)

    let reloadedStore = TextActionsPluginLocalStore(settingsDirectory: directory)
    #expect(reloadedStore.object(forKey: "TextActionsEnabled") as? Bool == true)
}

@Test func localStoreReportsFailureWhenSettingsDirectoryIsBlocked() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("TextActionsLocalStore-Blocked-\(UUID().uuidString)", isDirectory: true)
    let blockedDirectory = tempRoot.appendingPathComponent("settings", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    try "not a directory".write(to: blockedDirectory, atomically: true, encoding: .utf8)

    let store = TextActionsPluginLocalStore(settingsDirectory: blockedDirectory)

    #expect(store.set(true, forKey: "TextActionsEnabled") == false)
    #expect(store.object(forKey: "TextActionsEnabled") == nil)
}
