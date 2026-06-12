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

@Test func preferredConversationListWidthAllowsWidePanels() throws {
    let databaseDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LocalStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: databaseDirectory) }

    let store = LocalStore(databaseDirectory: databaseDirectory)
    store.saveConversationListWidth(780)

    #expect(SplitWidth.preferredWidth(databaseDirectory: databaseDirectory) == 780)
}

@Test func preferredConversationListWidthClampsOversizedValues() throws {
    let databaseDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LocalStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: databaseDirectory) }

    let store = LocalStore(databaseDirectory: databaseDirectory)
    store.saveConversationListWidth(1_200)

    #expect(SplitWidth.preferredWidth(databaseDirectory: databaseDirectory) == SplitWidth.defaultMaximumWidth)
}
