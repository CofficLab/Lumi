import Foundation
import Testing
@testable import PluginMindMapDesigner

/// 缓存的项目 store 不得用旧快照覆盖磁盘上的新编辑。
///
/// 复现场景：会话 A 缓存了项目 P 的 store（此时导图只有根节点），
/// 随后 UI 在同一项目里给导图加了子节点；会话 A 再更新该导图时，
/// 若基于旧快照写回，子节点会静默消失。
@Suite("MindMapStore 写前同步")
@MainActor
struct MindMapStoreSyncTests {

    private func makeProjectRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mindmap-sync-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func storageDirectory(for root: URL) -> URL {
        root
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent(MindMapDesignerRuntime.projectFolderName, isDirectory: true)
    }

    /// 从磁盘读回导图节点文本。
    private func nodeTexts(onDisk root: URL) -> [String] {
        MindMapFileStore.loadAll(storagePath: storageDirectory(for: root).path)
            .flatMap { $0.nodes.map(\.text) }
    }

    @Test("写操作前与磁盘对齐，不覆盖别处新增的节点")
    func writeDoesNotClobberNodesAddedElsewhere() throws {
        let root = try makeProjectRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        // 会话 A 的 store：加载时导图只有根节点。
        let scopedStore = MindMapDesignerRuntime.store(forProjectPath: root.path)
        let map = scopedStore.createMindMap(
            title: "Shared Map",
            rootText: "Root",
            direction: .right,
            scope: .project
        )
        #expect(scopedStore.projectMaps.first?.nodes.count == 1)

        // UI（另一个 store 实例）在同一项目里给导图加了子节点。
        let uiStore = MindMapStore()
        uiStore.setProjectStorage(
            projectPath: root.path,
            projectStorageDirectory: storageDirectory(for: root)
        )
        _ = try uiStore.addChildNodes(
            mapId: map.id,
            parentId: map.root!.id,
            texts: ["Child C"],
            color: nil,
            scope: .project
        )
        #expect(nodeTexts(onDisk: root).contains("Child C"))

        // 会话 A 现在更新根节点文本：不得把 Child C 抹掉。
        _ = try scopedStore.updateNode(
            mapId: map.id,
            nodeId: map.root!.id,
            scope: .project,
            text: "Root Renamed",
            note: nil,
            color: nil,
            collapsed: nil
        )

        let texts = nodeTexts(onDisk: root)
        #expect(texts.contains("Root Renamed"))
        #expect(texts.contains("Child C"), "写前同步应保留别处新增的节点")
    }

    @Test("新建导图不会挤掉磁盘上已有的导图")
    func createDoesNotDropExistingMaps() throws {
        let root = try makeProjectRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        // 会话 A 的 store：此时磁盘是空的。
        let scopedStore = MindMapDesignerRuntime.store(forProjectPath: root.path)
        _ = scopedStore.createMindMap(
            title: "From A",
            rootText: "A Root",
            direction: .right,
            scope: .project
        )

        // UI 在同一项目里新建了另一张导图。
        let uiStore = MindMapStore()
        uiStore.setProjectStorage(
            projectPath: root.path,
            projectStorageDirectory: storageDirectory(for: root)
        )
        uiStore.createMindMap(
            title: "From UI",
            rootText: "UI Root",
            direction: .right,
            scope: .project
        )

        // 会话 A 再新建一张：磁盘上原有的两张都要保留。
        _ = scopedStore.createMindMap(
            title: "From A Again",
            rootText: "A2 Root",
            direction: .right,
            scope: .project
        )

        let titles = MindMapFileStore.loadAll(storagePath: storageDirectory(for: root).path)
            .map(\.title)
        #expect(titles.count == 3)
        #expect(titles.contains("From A"))
        #expect(titles.contains("From UI"))
        #expect(titles.contains("From A Again"))

        // 内存列表也要与磁盘一致，否则 list_mind_maps 会漏掉 UI 新建的导图。
        let inMemoryTitles = scopedStore.projectMaps.map(\.title)
        #expect(inMemoryTitles.count == 3)
        #expect(inMemoryTitles.contains("From UI"))
    }

    @Test("删除别处创建的导图时以磁盘状态为准")
    func deleteUsesDiskState() throws {
        let root = try makeProjectRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        // 会话 A 的 store：此时磁盘是空的。
        let scopedStore = MindMapDesignerRuntime.store(forProjectPath: root.path)

        // UI 在同一项目里新建导图 X —— 会话 A 的缓存快照里没有它。
        let uiStore = MindMapStore()
        uiStore.setProjectStorage(
            projectPath: root.path,
            projectStorageDirectory: storageDirectory(for: root)
        )
        let map = uiStore.createMindMap(
            title: "Created By UI",
            rootText: "UI Root",
            direction: .right,
            scope: .project
        )
        #expect(!scopedStore.projectMaps.contains { $0.id == map.id })

        // 会话 A 删除 X：同步后应能找到并真正删除文件。
        scopedStore.deleteMindMap(id: map.id, scope: .project)

        let remaining = MindMapFileStore.loadAll(storagePath: storageDirectory(for: root).path)
        #expect(remaining.isEmpty, "磁盘上的文件应被删除")
        #expect(!scopedStore.projectMaps.contains { $0.id == map.id })
    }
}
