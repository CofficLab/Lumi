import KitAgentTool
import Foundation
import KernelCore
import ProviderActivityBar
import ProviderChatSection
import ProviderToolManager
import Testing
@testable import PluginMindMapDesigner

/// 跨对话隔离测试：Agent 工具必须按「调用所属对话」的项目读写，
/// 不能写到 UI 当前打开（可能属于另一个对话）的项目。
///
/// 思维导图的 store 是有状态单例（内存列表 + 落盘路径都跟随 UI 当前项目），
/// 因此修复方式是「按对话项目隔离 store 实例」：对话项目与 UI 当前项目不同时，
/// 使用指向该对话项目目录的独立实例。
extension MindMapDesignerPluginTests {
    /// 构造一个临时项目根目录。
    private func makeScopedProjectRoot(_ name: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mindmap-scope-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    /// 工具调用所属对话的项目（`nil` 表示对话未绑定项目）。
    private func conversationScopedContext(projectPath: String?) -> ToolExecutionContext {
        ToolExecutionContext(
            jobID: UUID().uuidString,
            conversationID: UUID(),
            conversationProjectPathProvider: { projectPath }
        )
    }

    /// 某项目下思维导图的文件名集合。
    private func scopedMapFiles(project: URL) -> Set<String> {
        let directory = project
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent(MindMapDesignerRuntime.projectFolderName, isDirectory: true)
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
            return []
        }
        return Set(names.filter { $0.hasSuffix(".json") })
    }

    @Test("对话 A 的工具调用写入对话 A 的项目，而不是 UI 当前打开的项目 B")
    func conversationScopedToolWritesIntoItsOwnProject() async throws {
        let projectA = try makeScopedProjectRoot("a")
        let projectB = try makeScopedProjectRoot("b")
        defer {
            try? FileManager.default.removeItem(at: projectA)
            try? FileManager.default.removeItem(at: projectB)
        }

        // UI 当前打开的是项目 B（用户切到了对话 B）。
        MindMapDesignerRuntime.reset()
        MindMapDesignerRuntime.updateProjectStorageDirectory(projectPath: projectB.path)

        // 但本次工具调用属于对话 A，其项目是 A。
        let tool = ConversationScopedMindMapTool(CreateMindMapTool())
        let context = conversationScopedContext(projectPath: projectA.path)

        let result = try await tool.executeResult(
            context: context,
            arguments: [
                "rootText": ToolArgument("Scoped Root"),
                "title": ToolArgument("Scoped Map"),
            ]
        )
        #expect(result.content.contains("Scoped Map"))

        // 期望：写入项目 A 的 .lumi/mind-map。
        #expect(scopedMapFiles(project: projectA).count == 1)

        // 失败症状：数据落到了项目 B。
        #expect(scopedMapFiles(project: projectB).isEmpty)
    }

    @Test("对话 A 的工具读取只看到项目 A 的思维导图")
    func conversationScopedToolReadsFromItsOwnProject() async throws {
        let projectA = try makeScopedProjectRoot("a")
        let projectB = try makeScopedProjectRoot("b")
        defer {
            try? FileManager.default.removeItem(at: projectA)
            try? FileManager.default.removeItem(at: projectB)
        }

        MindMapDesignerRuntime.reset()
        MindMapDesignerRuntime.updateProjectStorageDirectory(projectPath: projectB.path)

        // 项目 A 与项目 B 各有一张思维导图。
        let storeA = MindMapDesignerRuntime.store(forProjectPath: projectA.path)
        let mapA = storeA.createMindMap(
            title: "Only In A",
            rootText: "A Root",
            direction: .right,
            scope: .project
        )
        let storeB = MindMapDesignerRuntime.store(forProjectPath: projectB.path)
        let mapB = storeB.createMindMap(
            title: "Only In B",
            rootText: "B Root",
            direction: .right,
            scope: .project
        )

        let tool = ConversationScopedMindMapTool(ListMindMapsTool())
        let context = conversationScopedContext(projectPath: projectA.path)
        let result = try await tool.executeResult(context: context, arguments: [:])

        // 列表必须只包含项目 A 的思维导图。
        #expect(result.content.contains(mapA.id.prefix(8).description))
        #expect(!result.content.contains(mapB.id.prefix(8).description))
    }

    @Test("跨项目写入不会污染 UI 当前打开项目的面板")
    func crossProjectWriteDoesNotPolluteSharedStore() async throws {
        let projectA = try makeScopedProjectRoot("a")
        let projectB = try makeScopedProjectRoot("b")
        defer {
            try? FileManager.default.removeItem(at: projectA)
            try? FileManager.default.removeItem(at: projectB)
        }

        MindMapDesignerRuntime.reset()
        MindMapDesignerRuntime.updateProjectStorageDirectory(projectPath: projectB.path)

        // UI 当前项目（B）里已有一张思维导图，作为「面板已有内容」的基线。
        let sharedStore = MindMapStore.shared
        let existing = sharedStore.createMindMap(
            title: "Existing In B",
            rootText: "B Root",
            direction: .right,
            scope: .project
        )
        #expect(sharedStore.projectMaps.map(\.id) == [existing.id])

        let tool = ConversationScopedMindMapTool(CreateMindMapTool())
        let context = conversationScopedContext(projectPath: projectA.path)
        _ = try await tool.executeResult(
            context: context,
            arguments: [
                "rootText": ToolArgument("A Root"),
                "title": ToolArgument("Created In A"),
            ]
        )

        // UI 仍停在项目 B，面板内容不应被 A 的写入污染。
        #expect(MindMapStore.shared.projectMaps.map(\.id) == [existing.id])
        #expect(sharedStore.currentProjectPath == projectB.path)
    }

    @Test("对话绑定的项目与 UI 当前项目相同时复用共享 store，画布可实时刷新")
    func sameProjectReusesSharedStore() async throws {
        let projectA = try makeScopedProjectRoot("a")
        defer { try? FileManager.default.removeItem(at: projectA) }

        MindMapDesignerRuntime.reset()
        MindMapDesignerRuntime.updateProjectStorageDirectory(projectPath: projectA.path)

        let tool = ConversationScopedMindMapTool(CreateMindMapTool())
        let context = conversationScopedContext(projectPath: projectA.path)
        _ = try await tool.executeResult(
            context: context,
            arguments: [
                "rootText": ToolArgument("Same Root"),
                "title": ToolArgument("Same Project"),
            ]
        )

        // 同一项目：写入 shared，画布立刻能看到。
        #expect(MindMapStore.shared.projectMaps.count == 1)
        #expect(scopedMapFiles(project: projectA).count == 1)
    }

    @Test("未绑定项目的对话回退到 UI 当前打开项目")
    func unscopedConversationFallsBackToCurrentProject() async throws {
        let projectB = try makeScopedProjectRoot("b")
        defer { try? FileManager.default.removeItem(at: projectB) }

        MindMapDesignerRuntime.reset()
        MindMapDesignerRuntime.updateProjectStorageDirectory(projectPath: projectB.path)

        let tool = ConversationScopedMindMapTool(CreateMindMapTool())
        // conversationProjectPathProvider 返回 nil —— 对话未绑定项目。
        let context = conversationScopedContext(projectPath: nil)
        _ = try await tool.executeResult(
            context: context,
            arguments: [
                "rootText": ToolArgument("Fallback Root"),
                "title": ToolArgument("Fallback Map"),
            ]
        )

        #expect(scopedMapFiles(project: projectB).count == 1)
    }

    @Test("插件注册的 Agent 工具都带对话作用域包装")
    func registeredToolsAreConversationScoped() async throws {
        MindMapDesignerRuntime.reset()
        let kernel = KernelCoreContainer()
        let toolManager = DefaultToolManagerProviding()

        try kernel.registerProvider((any ToolManagerProviding).self, toolManager)
        try kernel.registerProvider((any ActivityBarProviding).self, DefaultActivityBarProviding())
        try kernel.registerProvider((any ChatSectionProviding).self, DefaultChatSectionProviding())

        try kernel.start(plugins: [MindMapDesignerPlugin()])
        try await kernel.enablePlugin(id: MindMapDesignerPlugin().id)

        let registered = toolManager.allTools().filter { $0.name.hasPrefix("list_mind_maps") || $0.name.hasPrefix("create_mind_map") }
        #expect(registered.count == 2)
        // 未包装的工具会退回「UI 当前打开项目」，多对话并行时串项目。
        #expect(registered.allSatisfy { $0 is ConversationScopedMindMapTool })

        try kernel.stop()
    }
}
