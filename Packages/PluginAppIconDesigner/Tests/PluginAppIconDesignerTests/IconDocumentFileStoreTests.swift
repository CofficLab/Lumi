import Foundation
import Testing
@testable import PluginAppIconDesigner

/// 回归 #292：文件名由标题派生，同一 ID 重命名后可能残留多个文件。
/// loadAll 必须按 ID 去重，delete 必须清除该 ID 的全部派生文件。
@Suite("IconDocumentFileStore")
struct IconDocumentFileStoreTests {
    private func makeDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("IconFileStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func jsonFiles(in directory: URL, id: String) -> [URL] {
        let suffix = "-\(id.prefix(8)).json"
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        )) ?? []
        return urls.filter { $0.pathExtension.lowercased() == "json" && $0.lastPathComponent.hasSuffix(suffix) }
    }

    @Test("delete 清除同一 ID 的全部派生文件，不只当前标题的主文件")
    func deleteClearsAllDerivedFilesOfID() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = UUID().uuidString
        let old = IconDocument(id: id, title: "Old Title")
        let new = IconDocument(id: id, title: "New Title")
        try IconDocumentFileStore.save(old, storagePath: directory.path)
        try IconDocumentFileStore.save(new, storagePath: directory.path)
        // 重命名后磁盘上同时存在两个同 ID 文件。
        #expect(jsonFiles(in: directory, id: id).count == 2)

        IconDocumentFileStore.delete(new, storagePath: directory.path)

        #expect(jsonFiles(in: directory, id: id).isEmpty, "delete 应清除该 ID 的全部派生文件，旧标题文件不得残留")
    }

    @Test("loadAll 按 ID 去重，保留最新修订而非按文件名取最后一条")
    func loadAllDeduplicatesByIDKeepingNewest() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = UUID().uuidString
        // 较新修订故意取字母序靠前的标题，证明去重按 updatedAt 而非文件名顺序。
        let newer = IconDocument(id: id, title: "AAA", updatedAt: Date(timeIntervalSince1970: 2_000))
        let older = IconDocument(id: id, title: "ZZZ", updatedAt: Date(timeIntervalSince1970: 1_000))
        try IconDocumentFileStore.save(older, storagePath: directory.path)
        try IconDocumentFileStore.save(newer, storagePath: directory.path)

        let loaded = IconDocumentFileStore.loadAll(storagePath: directory.path)

        #expect(loaded.count == 1, "同一 ID 只应保留一条当前版本")
        #expect(loaded.first?.id == id)
        #expect(loaded.first?.title == "AAA", "应保留 updatedAt 最新的修订")
    }

    @Test("delete 仍清除单一版本文档（常规路径不回归）")
    func deleteStillRemovesSingleVersion() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let document = IconDocument(title: "Solo")
        try IconDocumentFileStore.save(document, storagePath: directory.path)
        #expect(IconDocumentFileStore.loadAll(storagePath: directory.path).count == 1)

        IconDocumentFileStore.delete(document, storagePath: directory.path)

        #expect(IconDocumentFileStore.loadAll(storagePath: directory.path).isEmpty)
    }
}