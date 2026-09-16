import KitAgentTool
import Foundation
import KernelCore
import ProviderActivityBar
import ProviderChatSection
import Testing
@testable import PluginMindMapDesigner

@MainActor
@Suite("Mind map designer plugin", .serialized)
struct MindMapDesignerPluginTests {
    // MARK: - Plugin shape

    @Test func contributesRailTabAndCompleteToolSet() {
        let plugin = MindMapDesignerPlugin()
        #expect(plugin.id == "com.coffic.lumi.plugin.mind-map")
        #expect(plugin.order == 81)
        #expect(MindMapDesignerPlugin.railTabID == "mind-map.documents")
        let names = Set(MindMapDesignerPlugin.agentTools.map(\.name))
        #expect(names == [
            "list_mind_maps",
            "create_mind_map",
            "add_child_node",
            "update_node",
            "delete_node",
            "move_node",
            "save_mind_map",
            "load_mind_map",
            "export_mind_map",
            "import_outline",
        ])
    }

    @Test func activatingPluginShowsChatSectionAndDeactivatingRestoresIt() throws {
        let kernel = KernelCoreContainer()
        let activityBar = DefaultActivityBarProviding()
        let chat = DefaultChatSectionProviding()
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)

        let plugin = MindMapDesignerPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(activityBar.activeItemID == "\(plugin.id).entry")
        #expect(chat.isVisible)

        activityBar.activateItem(id: nil)

        #expect(chat.isVisible)
    }

    // MARK: - Markdown codec

    @Test func markdownCodecRoundTrip() throws {
        let outline = """
        # Topic
        - Branch A
          - Sub A1
          - Sub A2
        - Branch B
        """
        let map = MindMapMarkdownCodec.decode(markdown: outline, title: nil)
        #expect(map.title == "Topic")
        // root(Topic) + Branch A + Sub A1 + Sub A2 + Branch B = 5
        #expect(map.nodes.count == 5)
        let encoded = MindMapMarkdownCodec.encode(map)
        #expect(encoded.contains("Branch A"))
        #expect(encoded.contains("Sub A1"))
    }

    // MARK: - Layout engine

    @Test func layoutEngineProducesPositions() throws {
        let root = MindMapNode(parentId: nil, text: "Root")
        let child1 = MindMapNode(parentId: root.id, text: "Child 1")
        let child2 = MindMapNode(parentId: root.id, text: "Child 2")
        let grandchild = MindMapNode(parentId: child1.id, text: "Grandchild")
        let map = MindMap(title: "Test", nodes: [root, child1, child2, grandchild], layoutDirection: .bilateral)

        let result = MindMapLayoutEngine.layout(map)
        #expect(result.nodes.count == 4)
        #expect(result.nodes[root.id] != nil)
        // 双侧布局：两个子节点应分列根的左右（x 不同号）。
        let child1X = try #require(result.nodes[child1.id]).center.x
        let child2X = try #require(result.nodes[child2.id]).center.x
        #expect(child1X * child2X <= 0 || child1X != child2X, "children should spread on both sides")
        // bounds 非零。
        #expect(result.bounds.width > 0)
        #expect(result.bounds.height > 0)
    }

    // MARK: - Tree helpers

    @Test func descendantIds() {
        let root = MindMapNode(parentId: nil, text: "R")
        let a = MindMapNode(parentId: root.id, text: "A")
        let b = MindMapNode(parentId: a.id, text: "B")
        let c = MindMapNode(parentId: root.id, text: "C")
        let map = MindMap(title: "T", nodes: [root, a, b, c])
        #expect(map.descendantIds(of: root.id) == [a.id, b.id, c.id])
        #expect(map.descendantIds(of: a.id) == [b.id])
        #expect(map.descendantIds(of: c.id) == [])
    }

    @Test func wouldCreateCycle() {
        let root = MindMapNode(parentId: nil, text: "R")
        let a = MindMapNode(parentId: root.id, text: "A")
        let b = MindMapNode(parentId: a.id, text: "B")
        let map = MindMap(title: "T", nodes: [root, a, b])
        // 把 a 挂到 b（b 是 a 的后代）下应判环。
        #expect(map.wouldCreateCycle(nodeId: a.id, newParentId: b.id))
        // 把 a 挂到 root 下（合法）。
        #expect(!map.wouldCreateCycle(nodeId: a.id, newParentId: root.id))
    }

    // MARK: - End-to-end agent tools

    @Test func agentToolsBuildAndGrowMapInProjectScope() async throws {
        MindMapDesignerRuntime.reset()
        let projectRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectRoot) }
        MindMapDesignerRuntime.setProjectStorage(projectPath: projectRoot.path, projectStorageDirectory: projectRoot)

        let created = try await CreateMindMapTool().execute(
            arguments: [
                "rootText": ToolArgument("Swift Concurrency"),
                "title": ToolArgument("Concurrency"),
            ]
        )
        let mapId = try #require(firstUUID(in: created))
        #expect(await MainActor.run { MindMapStore.shared.selectedScope == .project })
        #expect(await MainActor.run { MindMapStore.shared.selectedMap?.id == mapId })

        let added = try await AddChildNodeTool().execute(
            arguments: [
                "mapId": ToolArgument(mapId),
                "parentId": ToolArgument(rootId(from: created)),
                "texts": ToolArgument(["async/await", "actors"]),
            ]
        )
        #expect(firstUUID(in: added) != nil) // 新建的子节点 id

        let updated = try await UpdateNodeTool().execute(
            arguments: [
                "mapId": ToolArgument(mapId),
                "nodeId": ToolArgument(childId(from: added)),
                "text": ToolArgument("Task Groups"),
            ]
        )
        // 更新成功：输出包含更新后的导图 id。
        #expect(firstUUID(in: updated) == mapId)

        let exported = try await ExportMindMapTool().execute(
            arguments: ["mapId": ToolArgument(mapId), "format": ToolArgument("markdown")]
        )
        #expect(exported.contains("Concurrency")) // map.title 作为标题行
        #expect(exported.contains("Task Groups")) // 更新后的子节点

        // 落盘确认。
        #expect(!MindMapFileStore.loadAll(storagePath: projectRoot.path).isEmpty)
    }

    @Test func mapsCannotBeCreatedWithoutAnOpenProject() async throws {
        MindMapDesignerRuntime.reset()
        let created = try await CreateMindMapTool().execute(
            arguments: ["rootText": ToolArgument("Project required")]
        )
        #expect(firstUUID(in: created) == nil)
        #expect(await MainActor.run { MindMapStore.shared.projectMaps.isEmpty })
    }

    // MARK: - Helpers

    private func rootId(from output: String) -> String {
        let line = output.split(whereSeparator: \.isNewline).first {
            $0.hasPrefix("根节点ID:") || $0.hasPrefix("rootId:")
        }!
        return line.split(separator: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
    }

    private func childId(from output: String) -> String {
        let line = output.split(whereSeparator: \.isNewline).first {
            $0.hasPrefix("节点ID:") || $0.hasPrefix("nodeId:")
        }!
        return line.split(separator: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
    }

    private func firstUUID(in output: String) -> String? {
        guard let range = output.range(of: #"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"#, options: .regularExpression) else {
            return nil
        }
        return String(output[range])
    }
}
