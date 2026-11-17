import Foundation
import Testing
@testable import PluginAppIconDesigner

/// 回归 #428：App Icon 文档更新先改内存再落盘，旧实现里 `persist` 吞掉写入错误、
/// `updateDocument` 随即把 `lastError` 清成 nil 并正常返回，工具据此上报「已更新」，
/// 改动只在内存里、重启即丢失。落盘失败必须向上抛出、还原内存、错误保持可见。
///
/// 用普通文件占据存储目录路径，使 `IconDocumentFileStore.save` 的 `createDirectory`
/// 确定性失败（ENOTDIR），不依赖权限或时序。
@MainActor
@Suite(.serialized)
struct IconDocumentSaveFailureTests {
    private func makeBase() throws -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("IconSaveFailure-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    /// 把存储目录路径占成普通文件，save 必然失败。
    private func blockedStorageURL(in base: URL) throws -> URL {
        let storageURL = base.appendingPathComponent("storage", isDirectory: true)
        try Data("blocker".utf8).write(to: storageURL)
        return storageURL
    }

    @Test("updateDocument 落盘失败时抛错、还原内存、错误保持可见")
    func updateDocumentThrowsAndRollsBackWhenSaveFails() throws {
        let base = try makeBase()
        defer { try? FileManager.default.removeItem(at: base) }
        let storageURL = try blockedStorageURL(in: base)

        let store = IconDocumentStore()
        store.setProjectStorage(projectPath: base.path, projectStorageDirectory: storageURL)
        // 导入即落盘失败：文档只在内存里，lastError 已记录。
        let document = store.importDocument(IconDocument(title: "Icon"), scope: .project)
        #expect(store.lastError != nil)
        let originalBackground = document.background

        #expect(throws: IconDocumentStoreError.self) {
            try store.updateDocument(id: document.id, scope: .project) { doc in
                doc.background = .color("#ff0000")
            }
        }

        // 内存还原为改动前的文档，错误不被清空。
        #expect(store.documents(for: .project).first?.background == originalBackground)
        #expect(store.documents(for: .project).first == document)
        #expect(store.lastError != nil)
    }

    @Test("replaceDocument 落盘失败时抛错并还原内存")
    func replaceDocumentThrowsAndRollsBackWhenSaveFails() throws {
        let base = try makeBase()
        defer { try? FileManager.default.removeItem(at: base) }
        let storageURL = try blockedStorageURL(in: base)

        let store = IconDocumentStore()
        store.setProjectStorage(projectPath: base.path, projectStorageDirectory: storageURL)
        let document = store.importDocument(IconDocument(title: "Icon"), scope: .project)

        var replacement = IconDocument(title: "Icon")
        replacement.background = .color("#00ff00")
        #expect(throws: IconDocumentStoreError.self) {
            try store.replaceDocument(replacement, replacingDocumentId: document.id, scope: .project)
        }

        #expect(store.documents(for: .project).first == document)
        #expect(store.lastError != nil)
    }

    @Test("可写存储下 updateDocument 正常落盘并清错（不回归）")
    func updateDocumentPersistsAndClearsErrorWhenSaveSucceeds() throws {
        let base = try makeBase()
        defer { try? FileManager.default.removeItem(at: base) }
        let storageURL = base.appendingPathComponent("storage", isDirectory: true)

        let store = IconDocumentStore()
        store.setProjectStorage(projectPath: base.path, projectStorageDirectory: storageURL)
        let document = store.importDocument(IconDocument(title: "Icon"), scope: .project)
        #expect(store.lastError == nil)

        let updated = try store.updateDocument(id: document.id, scope: .project) { doc in
            doc.background = .color("#ff0000")
        }

        #expect(store.lastError == nil)
        #expect(updated.background == .color("#ff0000"))
        let reloaded = IconDocumentFileStore.loadAll(storagePath: storageURL.path)
        #expect(reloaded.first?.id == document.id)
        #expect(reloaded.first?.background == .color("#ff0000"))
    }
}