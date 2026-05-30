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
