import Foundation
import Testing
@testable import PluginMindMapDesigner

/// 回归覆盖 issue #1061：磁盘删除失败时不得提交内存删除，
/// 否则地图会从列表消失、重载后又从磁盘复活。
@Suite("MindMapStore 删除失败")
@MainActor
struct MindMapDeleteFailureTests {

    @Test("删除文件失败时保留列表项与选中项并报告错误")
    func failedDeleteKeepsMapInList() throws {
        // root 无视目录写权限，无法制造删除失败。
        guard geteuid() != 0 else { return }

        let root = try makeProjectRoot()
        let storage = storageDirectory(for: root)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = MindMapStore()
        store.setProjectStorage(projectPath: root.path, projectStorageDirectory: storage)
        let map = store.createMindMap(title: "Budget", rootText: "Budget", direction: .right, scope: .project)
        let fileURL = storage.appendingPathComponent(MindMapFileStore.fileName(for: map))
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        let restore = try makeDirectoryReadOnly(storage)
        defer { restore() }

        store.deleteMindMap(id: map.id, scope: .project)

        #expect(store.projectMaps.map(\.id) == [map.id])
        #expect(store.selectedMapId == map.id)
        #expect(store.lastError != nil)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        // 重载后该地图仍在（修复前会先被内存移除，再被 loadAll 读回来）。
        store.reload()
        #expect(store.projectMaps.map(\.id) == [map.id])
    }

    @Test("标题与磁盘不一致走兜底删除时失败同样抛错")
    func fallbackDeleteThrowsWhenFileCannotBeRemoved() throws {
        // root 无视目录写权限，无法制造删除失败。
        guard geteuid() != 0 else { return }

        let root = try makeProjectRoot()
        let storage = storageDirectory(for: root)
        defer { try? FileManager.default.removeItem(at: root) }

        let onDisk = MindMap(title: "Old Title", nodes: [MindMapNode(text: "Root")])
        try MindMapFileStore.save(onDisk, storagePath: storage.path)
        var renamed = onDisk
        renamed.title = "New Title"
        #expect(MindMapFileStore.fileName(for: renamed) != MindMapFileStore.fileName(for: onDisk))

        let restore = try makeDirectoryReadOnly(storage)
        defer { restore() }

        #expect(throws: (any Error).self) {
            try MindMapFileStore.delete(renamed, storagePath: storage.path)
        }
        let fileURL = storage.appendingPathComponent(MindMapFileStore.fileName(for: onDisk))
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    // MARK: - Helpers

    private func makeProjectRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mindmap-delete-failure-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func storageDirectory(for root: URL) -> URL {
        root
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent(MindMapDesignerRuntime.projectFolderName, isDirectory: true)
    }

    /// 移除目录写权限，并返回恢复权限的闭包。
    private func makeDirectoryReadOnly(_ directory: URL) throws -> () -> Void {
        let original = try FileManager.default
            .attributesOfItem(atPath: directory.path)[.posixPermissions] as? NSNumber
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o555))],
            ofItemAtPath: directory.path
        )
        return {
            try? FileManager.default.setAttributes(
                [.posixPermissions: original ?? NSNumber(value: Int16(0o755))],
                ofItemAtPath: directory.path
            )
        }
    }
}
