import Foundation
import Testing
@testable import PluginMindMapDesigner

/// 回归覆盖 issue #429：磁盘保存失败时必须把错误抛给工具、保留错误状态，
/// 且内存与磁盘都不得提交这次修改，否则工具误报成功、重载后修改丢失。
@Suite("MindMapStore 保存失败")
@MainActor
struct MindMapSaveFailureTests {

    @Test("保存失败时抛错、保留错误状态且内存与磁盘不变")
    func failedSavePropagatesAndKeepsStateUnchanged() throws {
        // root 无视目录写权限，无法制造保存失败。
        guard geteuid() != 0 else { return }

        let root = try makeProjectRoot()
        let storage = storageDirectory(for: root)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = MindMapStore()
        store.setProjectStorage(projectPath: root.path, projectStorageDirectory: storage)
        let map = store.createMindMap(title: "Plan", rootText: "Original", direction: .right, scope: .project)
        let rootId = try #require(map.root?.id)
        #expect(diskNodeText(root: root, mapId: map.id, nodeId: rootId) == "Original")

        let restore = try makeDirectoryReadOnly(storage)
        defer { restore() }

        // 保存失败必须抛出，而不是返回成功。
        #expect(throws: (any Error).self) {
            try store.updateNode(
                mapId: map.id, nodeId: rootId, scope: .project,
                text: "Renamed", note: nil, color: nil, collapsed: nil
            )
        }

        // 错误状态保留，内存与磁盘都仍是旧文本。
        #expect(store.lastError != nil)
        #expect(store.projectMaps.first?.root?.text == "Original")
        #expect(diskNodeText(root: root, mapId: map.id, nodeId: rootId) == "Original")

        // 重载后仍是旧文本：修改没有「假成功」地丢失。
        store.reload()
        #expect(store.projectMaps.first?.root?.text == "Original")
    }

    @Test("可写时保存成功并同步内存与磁盘")
    func successfulSaveUpdatesMemoryAndDisk() throws {
        let root = try makeProjectRoot()
        let storage = storageDirectory(for: root)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = MindMapStore()
        store.setProjectStorage(projectPath: root.path, projectStorageDirectory: storage)
        let map = store.createMindMap(title: "Plan", rootText: "Original", direction: .right, scope: .project)
        let rootId = try #require(map.root?.id)

        let updated = try store.updateNode(
            mapId: map.id, nodeId: rootId, scope: .project,
            text: "Renamed", note: nil, color: nil, collapsed: nil
        )

        #expect(store.lastError == nil)
        #expect(updated.root?.text == "Renamed")
        #expect(store.projectMaps.first?.root?.text == "Renamed")
        #expect(diskNodeText(root: root, mapId: map.id, nodeId: rootId) == "Renamed")
    }

    // MARK: - Helpers

    private func makeProjectRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mindmap-save-failure-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func storageDirectory(for root: URL) -> URL {
        root
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent(MindMapDesignerRuntime.projectFolderName, isDirectory: true)
    }

    private func diskNodeText(root: URL, mapId: String, nodeId: String) -> String? {
        MindMapFileStore.loadAll(storagePath: storageDirectory(for: root).path)
            .first(where: { $0.id == mapId })?
            .node(id: nodeId)?.text
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