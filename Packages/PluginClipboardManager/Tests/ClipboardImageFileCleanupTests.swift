import Foundation
import SwiftData
import Testing

@testable import ClipboardManagerPlugin

// MARK: - Helpers

private func makeTemporaryDirectory(_ prefix: String) throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

/// 写一个插件自有命名（clipboard_<UUID>.png）的图片负载，返回其路径。
private func makeOwnedImageFile(in directory: URL) throws -> String {
    let url = directory.appendingPathComponent("clipboard_\(UUID().uuidString).png")
    try Data("png-bytes".utf8).write(to: url)
    return url.path
}

private func makeImageItem(
    path: String,
    timestamp: Date = Date(),
    isPinned: Bool = false
) -> ClipboardHistoryItem {
    ClipboardHistoryItem(
        timestamp: timestamp,
        type: ClipboardItemType.image.rawValue,
        content: path,
        isPinned: isPinned,
        searchKeywords: "image"
    )
}

// MARK: - Image file cleanup（回归 #244）

@Suite("Clipboard image file cleanup (#244)")
struct ClipboardImageFileCleanupTests {

    @Test("delete(id:) 删除记录时一并删除插件自有图片文件")
    func deleteRemovesPluginOwnedImageFile() async throws {
        let root = try makeTemporaryDirectory("clip244-delete")
        defer { try? FileManager.default.removeItem(at: root) }
        let manager = ClipboardHistoryManager(databaseDirectory: root)

        let path = try makeOwnedImageFile(in: root)
        let item = makeImageItem(path: path)
        #expect(await manager.add(item))
        #expect(FileManager.default.fileExists(atPath: path))

        #expect(await manager.delete(id: item.id))
        #expect(!FileManager.default.fileExists(atPath: path))
        #expect(await manager.getAll().isEmpty)
    }

    @Test("delete(ids:) 批量删除时删除各自的插件自有图片文件，保留其余")
    func batchDeleteRemovesPluginOwnedImageFiles() async throws {
        let root = try makeTemporaryDirectory("clip244-batch")
        defer { try? FileManager.default.removeItem(at: root) }
        let manager = ClipboardHistoryManager(databaseDirectory: root)

        let pathA = try makeOwnedImageFile(in: root)
        let pathB = try makeOwnedImageFile(in: root)
        let keepPath = try makeOwnedImageFile(in: root)
        let a = makeImageItem(path: pathA)
        let b = makeImageItem(path: pathB)
        let keep = makeImageItem(path: keepPath)
        #expect(await manager.addBatch([a, b, keep]))

        #expect(await manager.delete(ids: [a.id, b.id]))
        #expect(!FileManager.default.fileExists(atPath: pathA))
        #expect(!FileManager.default.fileExists(atPath: pathB))
        #expect(FileManager.default.fileExists(atPath: keepPath))
        #expect(await manager.getAll().map(\.id) == [keep.id])
    }

    @Test("clearAll 删除未固定图片文件，保留固定项及其文件")
    func clearAllRemovesUnpinnedImageFilesAndKeepsPinned() async throws {
        let root = try makeTemporaryDirectory("clip244-clear")
        defer { try? FileManager.default.removeItem(at: root) }
        let manager = ClipboardHistoryManager(databaseDirectory: root)

        let loosePath = try makeOwnedImageFile(in: root)
        let pinnedPath = try makeOwnedImageFile(in: root)
        #expect(await manager.addBatch([
            makeImageItem(path: loosePath),
            makeImageItem(path: pinnedPath, isPinned: true),
        ]))

        #expect(await manager.clearAll(keepPinned: true))
        #expect(!FileManager.default.fileExists(atPath: loosePath))
        #expect(FileManager.default.fileExists(atPath: pinnedPath))
        #expect(await manager.getAll().map(\.content) == [pinnedPath])
    }

    @Test("trimNonPinnedHistory 裁剪超额图片记录时删除其文件")
    func trimRemovesPluginOwnedImageFiles() async throws {
        let root = try makeTemporaryDirectory("clip244-trim")
        defer { try? FileManager.default.removeItem(at: root) }
        let manager = ClipboardHistoryManager(databaseDirectory: root)

        // 相对当前时间构造，避免被 30 天保留策略清理掉。
        let base = Date().addingTimeInterval(-200)
        let oldPath = try makeOwnedImageFile(in: root)
        let newPath = try makeOwnedImageFile(in: root)
        #expect(await manager.addBatch([
            makeImageItem(path: oldPath, timestamp: base),
            makeImageItem(path: newPath, timestamp: base.addingTimeInterval(100)),
        ]))

        // 保留最新 1 条，较旧的一条被裁剪，其文件应删除。
        #expect(await manager.trimNonPinnedHistory(keeping: 1) == 1)
        #expect(!FileManager.default.fileExists(atPath: oldPath))
        #expect(FileManager.default.fileExists(atPath: newPath))
    }

    @Test("过期清理删除超期图片文件，保留新记录与固定项文件")
    func expiryCleanupRemovesPluginOwnedImageFiles() async throws {
        let root = try makeTemporaryDirectory("clip244-expiry")
        defer { try? FileManager.default.removeItem(at: root) }
        let manager = ClipboardHistoryManager(databaseDirectory: root)

        let old = Date().addingTimeInterval(-40 * 24 * 60 * 60)
        let expiredPath = try makeOwnedImageFile(in: root)
        let freshPath = try makeOwnedImageFile(in: root)
        let pinnedPath = try makeOwnedImageFile(in: root)
        #expect(await manager.addBatch([
            makeImageItem(path: expiredPath, timestamp: old),
            makeImageItem(path: freshPath),
            makeImageItem(path: pinnedPath, timestamp: old, isPinned: true),
        ]))

        await manager.cleanup()
        #expect(!FileManager.default.fileExists(atPath: expiredPath))
        #expect(FileManager.default.fileExists(atPath: freshPath))
        #expect(FileManager.default.fileExists(atPath: pinnedPath))
    }

    @Test("删除图片记录不得误删外部路径或非图片条目的文件")
    func deletePreservesExternalAndNonImagePaths() async throws {
        let root = try makeTemporaryDirectory("clip244-external")
        defer { try? FileManager.default.removeItem(at: root) }
        let manager = ClipboardHistoryManager(databaseDirectory: root)

        // 外部命名（非 clipboard_<UUID>.png）的图片路径不得被删除。
        let externalURL = root.appendingPathComponent("user-photo.png")
        try Data("external".utf8).write(to: externalURL)
        let externalItem = makeImageItem(path: externalURL.path)

        // file 类型条目即使指向 clipboard_<UUID>.png 命名，也绝不可删除用户文件。
        let fileURL = root.appendingPathComponent("clipboard_\(UUID().uuidString).png")
        try Data("user-file".utf8).write(to: fileURL)
        let fileItem = ClipboardHistoryItem(
            type: ClipboardItemType.file.rawValue,
            content: fileURL.path,
            searchKeywords: "file"
        )

        #expect(await manager.addBatch([externalItem, fileItem]))
        #expect(await manager.delete(ids: [externalItem.id, fileItem.id]))

        #expect(FileManager.default.fileExists(atPath: externalURL.path))
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test("isPluginOwnedImageFilename 只认 clipboard_<UUID>.png")
    func pluginOwnedImageFilenameMatching() {
        #expect(ClipboardHistoryManager.isPluginOwnedImageFilename("clipboard_\(UUID().uuidString).png"))
        #expect(ClipboardHistoryManager.isPluginOwnedImageFilename("user-photo.png") == false)
        #expect(ClipboardHistoryManager.isPluginOwnedImageFilename("clipboard_not-a-uuid.png") == false)
        #expect(ClipboardHistoryManager.isPluginOwnedImageFilename("clipboard_\(UUID().uuidString).jpg") == false)
        #expect(ClipboardHistoryManager.isPluginOwnedImageFilename("clipboard_.png") == false)
        #expect(ClipboardHistoryManager.isPluginOwnedImageFilename("notes.txt") == false)
    }
}