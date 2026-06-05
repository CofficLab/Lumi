import Foundation
import Testing
@testable import ChatPanelPlugin

@Test func localStorePersistsConversationListWidth() throws {
    let databaseDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LocalStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: databaseDirectory) }

    let store = LocalStore(databaseDirectory: databaseDirectory)
    store.saveConversationListWidth(312)

    let reloadedStore = LocalStore(databaseDirectory: databaseDirectory)
    #expect(reloadedStore.loadConversationListWidth() == 312)

    let settingsURL = databaseDirectory
        .appendingPathComponent("ChatPanelPlugin", isDirectory: true)
        .appendingPathComponent("settings.plist")
    #expect(FileManager.default.fileExists(atPath: settingsURL.path))
}
