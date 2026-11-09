import KitAgentTool
import Foundation
import KernelCore
import ProviderActivityBar
import ProviderChatSection
import ProviderRootView
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

    @Test("地图数量变化同步 Rail 可见性（回归 #1020）")
    func mapAvailabilityChangesUpdateRailVisibility() throws {
        MindMapDesignerRuntime.reset()
        let projectRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("mindmap-rail-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        defer {
            MindMapDesignerRuntime.reset()
            try? FileManager.default.removeItem(at: projectRoot)
        }
        MindMapDesignerRuntime.setProjectStorage(
            projectPath: projectRoot.path,
            projectStorageDirectory: projectRoot
        )

        let rootView = DefaultRootViewProviding()
        let view = MindMapDesignerPlugin().makeDesignerView(rootView: rootView)
        #expect(MindMapStore.shared.projectMaps.isEmpty)

        // 空列表：Rail 隐藏。
        view.notifyMapAvailability()
        #expect(!rootView.isRailViewVisible)

        // Agent 创建首张图：Rail 出现。
        let map = MindMapStore.shared.createMindMap(
            title: "First",
            rootText: "Root",
            direction: .right,
            scope: .project
        )
        view.notifyMapAvailability()
        #expect(rootView.isRailViewVisible)

        // 删除最后一张图：Rail 再次隐藏。
        MindMapStore.shared.deleteMindMap(id: map.id, scope: .project)
        #expect(MindMapStore.shared.projectMaps.isEmpty)
        view.notifyMapAvailability()
        #expect(!rootView.isRailViewVisible)
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

    @Test("加入项目不预建存储目录，真正写入时才创建")
    func doesNotCreateStorageDirectoryUntilWrite() throws {
        MindMapDesignerRuntime.reset()
        let projectRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("mindmap-lazy-dir-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        defer {
            MindMapDesignerRuntime.reset()
            try? FileManager.default.removeItem(at: projectRoot)
        }

        let storage = projectRoot
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent(MindMapDesignerRuntime.projectFolderName, isDirectory: true)

        MindMapDesignerRuntime.setProjectStorage(projectPath: projectRoot.path, projectStorageDirectory: storage)

        // 仅打开项目不应留下空目录。
        #expect(!FileManager.default.fileExists(atPath: storage.path))
        #expect(MindMapStore.shared.projectMaps.isEmpty)

        // 真正创建思维导图时才创建目录。
        _ = MindMapStore.shared.createMindMap(
            title: "Lazy Map",
            rootText: "Root",
            direction: .right,
            scope: .project
        )
        #expect(FileManager.default.fileExists(atPath: storage.path))
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

    @Test func saveMindMapRecreatesMissingBackingFile() async throws {
        MindMapDesignerRuntime.reset()
        let projectRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        defer {
            MindMapDesignerRuntime.reset()
            try? FileManager.default.removeItem(at: projectRoot)
        }
        MindMapDesignerRuntime.setProjectStorage(projectPath: projectRoot.path, projectStorageDirectory: projectRoot)

        let created = try await CreateMindMapTool().execute(
            arguments: ["rootText": ToolArgument("Root"), "title": ToolArgument("Saver")]
        )
        let mapId = try #require(firstUUID(in: created))
        let storagePath = await MainActor.run { MindMapStore.shared.projectStoragePath }

        // 删除 backing JSON，但地图仍在当前 Store 内存里。
        for file in try FileManager.default.contentsOfDirectory(atPath: storagePath) {
            try FileManager.default.removeItem(
                at: URL(fileURLWithPath: storagePath).appendingPathComponent(file)
            )
        }
        #expect(await MainActor.run { MindMapStore.shared.projectMaps.contains { $0.id == mapId } })

        let saved = try await SaveMindMapTool().execute(arguments: ["mapId": ToolArgument(mapId)])
        #expect(saved.contains(mapId))

        let reloaded = MindMapFileStore.loadAll(storagePath: storagePath)
        #expect(reloaded.contains { $0.id == mapId })
        #expect(await MainActor.run { MindMapStore.shared.projectMaps.contains { $0.id == mapId } })
    }

    @Test func saveMindMapReportsWriteFailure() async throws {
        MindMapDesignerRuntime.reset()
        let projectRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        defer {
            MindMapDesignerRuntime.reset()
            try? FileManager.default.removeItem(at: projectRoot)
        }
        MindMapDesignerRuntime.setProjectStorage(projectPath: projectRoot.path, projectStorageDirectory: projectRoot)

        let created = try await CreateMindMapTool().execute(
            arguments: ["rootText": ToolArgument("Root"), "title": ToolArgument("Broken")]
        )
        let mapId = try #require(firstUUID(in: created))
        let storagePath = await MainActor.run { MindMapStore.shared.projectStoragePath }

        // 用普通文件占住存储目录路径，使写入必然失败。
        try FileManager.default.removeItem(at: URL(fileURLWithPath: storagePath))
        try Data().write(to: URL(fileURLWithPath: storagePath))

        await #expect(throws: (any Error).self) {
            _ = try await SaveMindMapTool().execute(arguments: ["mapId": ToolArgument(mapId)])
        }
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

// MARK: - 大纲解析的健壮性

/// 大纲文本由用户或模型提供，任何输入都不能让解析器崩溃。
@Suite("MindMapMarkdownCodec 健壮性")
struct MindMapMarkdownCodecRobustnessTests {

    @Test("根节点之后的普通文本被忽略而不崩溃")
    func ignoresPlainTextAfterRoot() {
        // 旧实现：第二个裸文本行带着 indent == -1 落进列表层级逻辑，
        // safeIndex 算成 -1，访问 stack[-1] 触发越界 trap。
        let map = MindMapMarkdownCodec.decode(markdown: "Root\nNotes", title: nil)

        #expect(map.nodes.count == 1)
        #expect(map.nodes.first?.text == "Root")
    }

    @Test("根节点之后的标题行被忽略而不崩溃")
    func ignoresHeadingAfterRoot() {
        let map = MindMapMarkdownCodec.decode(markdown: "# Root\n- Child\n## Notes", title: nil)

        #expect(map.nodes.count == 2)
        #expect(map.nodes.contains { $0.text == "Child" })
        #expect(!map.nodes.contains { $0.text == "Notes" })
    }

    @Test("列表项之间的普通文本被忽略而不崩溃")
    func ignoresPlainTextBetweenListItems() {
        let map = MindMapMarkdownCodec.decode(
            markdown: "- Branch A\nSome prose\n- Branch B",
            title: nil
        )

        #expect(map.nodes.count == 3)
        #expect(!map.nodes.contains { $0.text == "Some prose" })
    }

    @Test("纯文本大纲仍能创建根节点")
    func plainTextOutlineStillCreatesRoot() {
        let map = MindMapMarkdownCodec.decode(markdown: "Just A Root", title: nil)

        #expect(map.nodes.count == 1)
        #expect(map.nodes.first?.text == "Just A Root")
        #expect(map.nodes.first?.parentId == nil)
    }

    @Test("空大纲得到一个兜底根节点")
    func emptyOutlineProducesFallbackRoot() {
        let map = MindMapMarkdownCodec.decode(markdown: "   \n  \n", title: nil)

        #expect(map.nodes.count == 1)
        #expect(map.nodes.first?.parentId == nil)
    }

    @Test("显式 title 不被 Markdown 标题覆盖（回归 #1082）")
    func explicitTitleWinsOverHeading() {
        let map = MindMapMarkdownCodec.decode(markdown: "# Source Heading\n- Branch", title: "Custom Title")

        #expect(map.title == "Custom Title")
        #expect(map.nodes.first?.text == "Custom Title")
        #expect(map.nodes.contains { $0.text == "Branch" })
        #expect(!map.nodes.contains { $0.text == "Source Heading" })
    }

    @Test("空白 title 回退到 Markdown 首个标题")
    func blankTitleFallsBackToHeading() {
        let map = MindMapMarkdownCodec.decode(markdown: "# Source Heading\n- Branch", title: "   ")

        #expect(map.title == "Source Heading")
        #expect(map.nodes.first?.text == "Source Heading")
    }

    @Test("同级 Tab 缩进生成兄弟节点（回归 #1081）")
    func tabIndentedSiblingsStaySiblings() throws {
        let map = MindMapMarkdownCodec.decode(markdown: "# Topic\n- A\n\t- A1\n\t- A2", title: nil)
        let a = try #require(map.nodes.first { $0.text == "A" })

        #expect(map.nodes.count == 4)
        #expect(map.nodes.first { $0.text == "A1" }?.parentId == a.id)
        #expect(map.nodes.first { $0.text == "A2" }?.parentId == a.id)
        #expect(!map.nodes.contains { node in
            node.text == "A2" && map.nodes.contains { $0.id == node.parentId && $0.text == "A1" }
        })
    }

    @Test("Tab 与两空格缩进产生相同结构")
    func tabAndSpaceIndentationProduceSameShape() {
        let tabbed = MindMapMarkdownCodec.decode(markdown: "# Topic\n- A\n\t- A1\n\t- A2", title: nil)
        let spaced = MindMapMarkdownCodec.decode(markdown: "# Topic\n- A\n  - A1\n  - A2", title: nil)

        func parentTexts(_ map: MindMap) -> [String: String?] {
            let textByID = Dictionary(uniqueKeysWithValues: map.nodes.map { ($0.id, $0.text) })
            return Dictionary(uniqueKeysWithValues: map.nodes.map { node in
                (node.text, node.parentId.flatMap { textByID[$0] })
            })
        }
        #expect(parentTexts(tabbed) == parentTexts(spaced))
    }
}
