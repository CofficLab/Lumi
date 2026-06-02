import CryptoKit
import Foundation
import Testing
@testable import EditorTabStripPlugin

@Test func packageLoads() async throws {
    #expect(EditorTabStripPlugin.id == "EditorTabStrip")
}

@Test func storeQuarantinesInvalidTabsSnapshotAndRecovers() async throws {
    let baseDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("EditorTabStripStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: baseDirectory) }

    let projectPath = "/tmp/Lumi"
    let projectDirectory = baseDirectory.appendingPathComponent(stableDirectoryName(for: projectPath), isDirectory: true)
    try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)

    let tabsURL = projectDirectory.appendingPathComponent("tabs.json")
    let corruptURL = projectDirectory.appendingPathComponent("tabs.corrupt.json")
    let invalidData = Data("not json".utf8)
    try invalidData.write(to: tabsURL)

    let store = EditorTabStripStore(baseDirectory: baseDirectory)

    let emptyTabs = store.loadTabs(forProject: projectPath)
    #expect(emptyTabs.tabs.isEmpty)
    #expect(emptyTabs.activeTabPath == nil)
    #expect((try? Data(contentsOf: corruptURL)) == invalidData)

    let filePath = "/tmp/Lumi/App.swift"
    store.setCurrentFilePath(path: filePath, forProject: projectPath)

    let recoveredTabs = try await loadTabsEventually(from: store, projectPath: projectPath, activePath: filePath)
    #expect(recoveredTabs.tabs.map(\.path) == [filePath])
    #expect(recoveredTabs.activeTabPath == filePath)
}

private func loadTabsEventually(
    from store: EditorTabStripStore,
    projectPath: String,
    activePath: String
) async throws -> (tabs: [EditorTabStripStore.PersistedTab], activeTabPath: String?) {
    for _ in 0..<50 {
        let loaded = store.loadTabs(forProject: projectPath)
        if loaded.activeTabPath == activePath {
            return loaded
        }
        try await Task.sleep(for: .milliseconds(20))
    }

    return store.loadTabs(forProject: projectPath)
}

private func stableDirectoryName(for projectPath: String) -> String {
    let hash = SHA256.hash(data: Data(projectPath.utf8))
    let hex = hash.compactMap { String(format: "%02x", $0) }.joined()
    return "project_\(String(hex.prefix(16)))"
}
