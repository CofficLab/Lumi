import KitAgentTool
import Foundation
import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderRailView
import ProviderStorage
import ProviderToolManager
import Testing
@testable import PluginAppIconDesigner

/// 跨对话隔离测试：Agent 工具必须按「调用所属对话」的项目读写，
/// 不能写到 UI 当前打开（可能属于另一个对话）的项目。
///
/// 图标设计器的 store 是有状态单例（内存列表 + 落盘路径都跟随 UI 当前项目），
/// 因此修复方式是「按对话项目隔离 store 实例」：对话项目与 UI 当前项目不同时，
/// 使用指向该对话项目目录的独立实例。
extension AppIconDesignerPluginTests {
    /// 构造一个临时项目根目录。
    private func makeScopedProjectRoot(_ name: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("icon-scope-\(name)-\(UUID().uuidString)", isDirectory: true)
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

    /// 某项目下图标文档的存储目录。
    private func scopedStorageURL(project: URL) -> URL {
        project
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent(IconDesignerRuntime.projectFolderName, isDirectory: true)
    }

    /// 某项目下的图标文档文件名集合。
    private func scopedDocumentFiles(project: URL) -> Set<String> {
        let directory = scopedStorageURL(project: project)
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
        IconDesignerRuntime.reset()
        IconDesignerRuntime.updateProjectStorageDirectory(projectPath: projectB.path)

        // 但本次工具调用属于对话 A，其项目是 A。
        let tool = ConversationScopedIconTool(CreateIconDocumentTool())
        let context = conversationScopedContext(projectPath: projectA.path)

        let result = try await tool.executeResult(
            context: context,
            arguments: ["title": ToolArgument("Scoped Icon")]
        )
        #expect(result.content.contains("Scoped Icon"))

        // 期望：写入项目 A 的 .lumi/app-icon-designer。
        #expect(scopedDocumentFiles(project: projectA).count == 1)

        // 失败症状：数据落到了项目 B。
        #expect(scopedDocumentFiles(project: projectB).isEmpty)
    }

    @Test("对话 A 的工具读取只看到项目 A 的文档")
    func conversationScopedToolReadsFromItsOwnProject() async throws {
        let projectA = try makeScopedProjectRoot("a")
        let projectB = try makeScopedProjectRoot("b")
        defer {
            try? FileManager.default.removeItem(at: projectA)
            try? FileManager.default.removeItem(at: projectB)
        }

        IconDesignerRuntime.reset()
        IconDesignerRuntime.updateProjectStorageDirectory(projectPath: projectB.path)

        // 项目 A 与项目 B 各有一个文档。
        let storeA = IconDesignerRuntime.store(forProjectPath: projectA.path)
        let docA = storeA.createDocument(
            title: "Only In A",
            width: 1024,
            height: 1024,
            background: .color("#00000000"),
            scope: .project
        )
        let storeB = IconDesignerRuntime.store(forProjectPath: projectB.path)
        let docB = storeB.createDocument(
            title: "Only In B",
            width: 1024,
            height: 1024,
            background: .color("#00000000"),
            scope: .project
        )

        let tool = ConversationScopedIconTool(ListIconDocumentsTool())
        let context = conversationScopedContext(projectPath: projectA.path)
        let result = try await tool.executeResult(context: context, arguments: [:])

        // 列表必须只包含项目 A 的文档。
        #expect(result.content.contains(docA.id))
        #expect(!result.content.contains(docB.id))
    }

    @Test("跨项目写入不会污染 UI 当前打开项目的面板")
    func crossProjectWriteDoesNotPolluteSharedStore() async throws {
        let projectA = try makeScopedProjectRoot("a")
        let projectB = try makeScopedProjectRoot("b")
        defer {
            try? FileManager.default.removeItem(at: projectA)
            try? FileManager.default.removeItem(at: projectB)
        }

        IconDesignerRuntime.reset()
        IconDesignerRuntime.updateProjectStorageDirectory(projectPath: projectB.path)

        // UI 当前项目（B）里已有一个文档，作为「面板已有内容」的基线。
        let sharedStore = IconDocumentStore.shared
        let existing = sharedStore.createDocument(
            title: "Existing In B",
            width: 1024,
            height: 1024,
            background: .color("#00000000"),
            scope: .project
        )
        #expect(sharedStore.projectDocuments.map(\.id) == [existing.id])

        let tool = ConversationScopedIconTool(CreateIconDocumentTool())
        let context = conversationScopedContext(projectPath: projectA.path)
        _ = try await tool.executeResult(
            context: context,
            arguments: ["title": ToolArgument("Created In A")]
        )

        // UI 仍停在项目 B，面板内容不应被 A 的写入污染。
        #expect(IconDocumentStore.shared.projectDocuments.map(\.id) == [existing.id])
        #expect(sharedStore.currentProjectPath == projectB.path)
    }

    @Test("对话绑定的项目与 UI 当前项目相同时复用共享 store，画布可实时刷新")
    func sameProjectReusesSharedStore() async throws {
        let projectA = try makeScopedProjectRoot("a")
        defer { try? FileManager.default.removeItem(at: projectA) }

        IconDesignerRuntime.reset()
        IconDesignerRuntime.updateProjectStorageDirectory(projectPath: projectA.path)

        let tool = ConversationScopedIconTool(CreateIconDocumentTool())
        let context = conversationScopedContext(projectPath: projectA.path)
        _ = try await tool.executeResult(
            context: context,
            arguments: ["title": ToolArgument("Same Project")]
        )

        // 同一项目：写入 shared，画布立刻能看到。
        #expect(IconDocumentStore.shared.projectDocuments.count == 1)
        #expect(scopedDocumentFiles(project: projectA).count == 1)
    }

    @Test("未绑定项目的对话回退到 UI 当前打开项目")
    func unscopedConversationFallsBackToCurrentProject() async throws {
        let projectB = try makeScopedProjectRoot("b")
        defer { try? FileManager.default.removeItem(at: projectB) }

        IconDesignerRuntime.reset()
        IconDesignerRuntime.updateProjectStorageDirectory(projectPath: projectB.path)

        let tool = ConversationScopedIconTool(CreateIconDocumentTool())
        // conversationProjectPathProvider 返回 nil —— 对话未绑定项目。
        let context = conversationScopedContext(projectPath: nil)
        _ = try await tool.executeResult(
            context: context,
            arguments: ["title": ToolArgument("Fallback Icon")]
        )

        #expect(scopedDocumentFiles(project: projectB).count == 1)
    }

    @Test("插件注册的 Agent 工具都带对话作用域包装")
    func registeredToolsAreConversationScoped() async throws {
        IconDesignerRuntime.reset()
        let kernel = KernelCoreContainer()
        let toolManager = DefaultToolManagerProviding()
        let storage = TestStorage()

        try kernel.registerProvider((any ToolManagerProviding).self, toolManager)
        try kernel.registerProvider((any ActivityBarProviding).self, DefaultActivityBarProviding())
        try kernel.registerProvider(
            (any ContentViewProviding).self,
            DefaultContentViewProviding()
        )
        try kernel.registerProvider((any RailViewProviding).self, DefaultRailViewProviding())
        try kernel.registerProvider((any StorageProviding).self, storage)

        try kernel.start(plugins: [AppIconDesignerPlugin()])
        try await kernel.enablePlugin(id: AppIconDesignerPlugin().id)

        let registered = toolManager.allTools().filter { $0.name.hasPrefix("list_icon_documents") || $0.name.hasPrefix("create_icon_document") }
        #expect(registered.count == 2)
        // 未包装的工具会退回「UI 当前打开项目」，多对话并行时串项目。
        #expect(registered.allSatisfy { $0 is ConversationScopedIconTool })

        try kernel.stop()
        try? FileManager.default.removeItem(at: storage.dataRootDirectory)
    }
}
