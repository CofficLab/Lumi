import Foundation
import Testing
@testable import PluginWindowPersistence

@Test func consecutiveAsyncSavesMergeWithLatestRecord() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("WindowStateStoreTests-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let store = WindowStateStore(databaseRootURLProvider: { directory })
    let windowId = UUID()
    let conversationId = UUID()
    let projectPath = "/tmp/LumiProject"
    let openFiles = ["/tmp/LumiProject/A.swift", "/tmp/LumiProject/B.swift"]
    let activeFile = "/tmp/LumiProject/B.swift"

    store.saveProject(windowId: windowId, projectPath: projectPath)
    store.saveConversation(windowId: windowId, conversationId: conversationId)
    store.saveEditor(windowId: windowId, editorOpenFilePaths: openFiles, editorActiveFilePath: activeFile)
    store.saveSidebar(windowId: windowId, sidebarVisibility: true)

    let record = try #require(store.record(for: windowId))
    #expect(record.projectPath == projectPath)
    #expect(record.conversationId == conversationId)
    #expect(record.editorOpenFilePaths == openFiles)
    #expect(record.editorActiveFilePath == activeFile)
    #expect(record.sidebarVisibility == true)
}

@Test func corruptWindowStateFileIsQuarantinedAndCanRecover() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("WindowStateStoreCorruptTests-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let settingsDirectory = directory
        .appendingPathComponent("WindowPersistence", isDirectory: true)
        .appendingPathComponent("settings", isDirectory: true)
    try FileManager.default.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)

    let statesURL = settingsDirectory.appendingPathComponent("window_states.json")
    let corruptURL = settingsDirectory.appendingPathComponent("window_states.corrupt.json")
    let invalidData = Data("not json".utf8)
    try invalidData.write(to: statesURL)

    let store = WindowStateStore(databaseRootURLProvider: { directory })

    #expect(store.loadAll().isEmpty)
    #expect((try? Data(contentsOf: corruptURL)) == invalidData)

    let record = WindowPersistenceRecord(
        windowId: UUID(),
        conversationId: UUID(),
        projectPath: "/tmp/LumiProject",
        editorOpenFilePaths: ["/tmp/LumiProject/App.swift"],
        editorActiveFilePath: "/tmp/LumiProject/App.swift",
        sidebarVisibility: true,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    store.saveAllSynchronously([record])

    let reloaded = store.loadAll()
    #expect(reloaded.count == 1)
    #expect(reloaded.first?.windowId == record.windowId)
    #expect(reloaded.first?.conversationId == record.conversationId)
    #expect(reloaded.first?.projectPath == record.projectPath)
    #expect(reloaded.first?.editorOpenFilePaths == record.editorOpenFilePaths)
    #expect(reloaded.first?.editorActiveFilePath == record.editorActiveFilePath)
    #expect(reloaded.first?.sidebarVisibility == record.sidebarVisibility)
}
