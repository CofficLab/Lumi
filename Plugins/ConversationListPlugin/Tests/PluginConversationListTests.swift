import Foundation
import LumiCoreKit
import Testing
@testable import ConversationListPlugin

@Test func packageLoads() async throws {
    #expect(ConversationListPlugin.info.id == "com.coffic.lumi.plugin.conversation-list")
    #expect(ConversationListPlugin.info.displayName.isEmpty == false)
    #expect(ConversationListPlugin.info.description.isEmpty == false)
    #expect(ConversationListPlugin.iconName == "message.fill")
    #expect(ConversationListPlugin.category == .agent)
}

@MainActor
@Test func pluginRegistersProjectSwitchMiddleware() {
    let middlewares = ConversationListPlugin.sendMiddlewares(
        context: LumiPluginContext(activeSectionID: "chat", activeSectionTitle: "Chat")
    )
    #expect(middlewares.count == 1)
}

@Test func localStoreSavesAndReloadsSelectedConversationId() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ConversationListLocalStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let selectedId = UUID()
    let store = ConversationListLocalStore(settingsDirectory: directory)

    #expect(store.saveSelectedConversationId(selectedId) == true)

    let reloadedStore = ConversationListLocalStore(settingsDirectory: directory)
    #expect(reloadedStore.loadSelectedConversationId() == selectedId)
}

@Test func localStoreQuarantinesInvalidSelectionFileAndRecovers() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ConversationListLocalStore-Invalid-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let selectionURL = directory.appendingPathComponent("conversation_selection.plist")
    let corruptURL = directory.appendingPathComponent("conversation_selection.corrupt.plist")
    let invalidData = Data("not a plist".utf8)
    try invalidData.write(to: selectionURL)

    let selectedId = UUID()
    let store = ConversationListLocalStore(settingsDirectory: directory)

    #expect(store.saveSelectedConversationId(selectedId) == true)
    #expect((try? Data(contentsOf: corruptURL)) == invalidData)
    #expect(store.loadSelectedConversationId() == selectedId)

    let reloadedStore = ConversationListLocalStore(settingsDirectory: directory)
    #expect(reloadedStore.loadSelectedConversationId() == selectedId)
}

@Test func localStoreReportsFailureWhenSelectionDirectoryIsBlocked() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("ConversationListLocalStore-Blocked-\(UUID().uuidString)", isDirectory: true)
    let blockedDirectory = tempRoot.appendingPathComponent("settings", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    try "not a directory".write(to: blockedDirectory, atomically: true, encoding: .utf8)

    let store = ConversationListLocalStore(settingsDirectory: blockedDirectory)

    #expect(store.saveSelectedConversationId(UUID()) == false)
    #expect(store.loadSelectedConversationId() == nil)
}
