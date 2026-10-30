import KitAgentTool
import Foundation
import KernelCore
import KitResume
import ProviderActivityBar
import ProviderContentView
import ProviderRailView
import ProviderStorage
import ProviderToolManager
import Testing
@testable import PluginResumeDesigner

/// 跨对话隔离测试：Agent 工具必须按「调用所属对话」的项目读写，
/// 不能写到 UI 当前打开（可能属于另一个对话）的项目。
///
/// 场景：对话 A 绑定项目 A，Agent 正在执行工具；此时用户切到对话 B，
/// 内核把「当前打开项目」切到 B。旧实现从 `WorkspaceStore.shared`
/// （跟随 UI 当前项目）取路径，于是 A 的工具调用写进了 B。
extension ResumeDesignerSuite {
    /// 构造一个临时项目根目录。
    private func makeScopedProjectRoot(_ name: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("resume-scope-\(name)-\(UUID().uuidString)", isDirectory: true)
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

    /// 某项目下简历 manifest 的路径。
    private func scopedManifestURL(project: URL, slug: String) -> URL {
        project
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent(ResumeDesignerRuntime.projectFolderName, isDirectory: true)
            .appendingPathComponent("resumes", isDirectory: true)
            .appendingPathComponent(slug, isDirectory: true)
            .appendingPathComponent("manifest.json", isDirectory: false)
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
        ResumeDesignerRuntime.reset()
        let storageB = projectB
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent(ResumeDesignerRuntime.projectFolderName, isDirectory: true)
        ResumeDesignerRuntime.setProjectStorage(projectPath: projectB.path, projectStorageDirectory: storageB)

        // 但本次工具调用属于对话 A，其项目是 A。
        let tool = ConversationScopedResumeTool(CreateResumeTool())
        let context = conversationScopedContext(projectPath: projectA.path)

        let result = try await tool.executeResult(
            context: context,
            arguments: arguments([
                "slug": "scoped-resume",
                "title": "Scoped Resume",
                "paper": "a4",
                "template": "classic",
            ])
        )
        #expect(result.content.contains("scoped-resume"))

        // 期望：写入项目 A 的 .lumi/resume-designer。
        #expect(FileManager.default.fileExists(atPath: scopedManifestURL(project: projectA, slug: "scoped-resume").path))

        // 失败症状：数据落到了项目 B。
        #expect(!FileManager.default.fileExists(atPath: scopedManifestURL(project: projectB, slug: "scoped-resume").path))
    }

    @Test("对话 A 的工具读取只看到项目 A 的简历")
    func conversationScopedToolReadsFromItsOwnProject() async throws {
        let projectA = try makeScopedProjectRoot("a")
        let projectB = try makeScopedProjectRoot("b")
        defer {
            try? FileManager.default.removeItem(at: projectA)
            try? FileManager.default.removeItem(at: projectB)
        }

        ResumeDesignerRuntime.reset()
        let storageB = projectB
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent(ResumeDesignerRuntime.projectFolderName, isDirectory: true)
        ResumeDesignerRuntime.setProjectStorage(projectPath: projectB.path, projectStorageDirectory: storageB)

        // 项目 A 与项目 B 各有一份简历。
        let store = ResumeDocumentStore()
        _ = try store.createResume(
            storagePath: ResumeDesignerRuntime.resumeStorageDirectory(forProjectPath: projectA.path)!.path,
            slug: "only-in-a",
            title: "Only In A",
            paper: .a4,
            template: .classic
        )
        _ = try store.createResume(
            storagePath: ResumeDesignerRuntime.resumeStorageDirectory(forProjectPath: projectB.path)!.path,
            slug: "only-in-b",
            title: "Only In B",
            paper: .a4,
            template: .classic
        )

        let tool = ConversationScopedResumeTool(ListResumesTool())
        let context = conversationScopedContext(projectPath: projectA.path)
        let result = try await tool.executeResult(context: context, arguments: [:])

        // 列表必须只包含项目 A 的简历。
        #expect(result.content.contains("only-in-a"))
        #expect(!result.content.contains("only-in-b"))
    }

    @Test("跨项目写入不会刷新 UI 当前打开项目的面板")
    func crossProjectWriteDoesNotReloadWorkspaceOfAnotherProject() async throws {
        let projectA = try makeScopedProjectRoot("a")
        let projectB = try makeScopedProjectRoot("b")
        defer {
            try? FileManager.default.removeItem(at: projectA)
            try? FileManager.default.removeItem(at: projectB)
        }

        ResumeDesignerRuntime.reset()
        let storageB = projectB
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent(ResumeDesignerRuntime.projectFolderName, isDirectory: true)
        ResumeDesignerRuntime.setProjectStorage(projectPath: projectB.path, projectStorageDirectory: storageB)

        // 让 UI 当前项目（B）里已有一份简历，作为「面板已有内容」的基线。
        _ = try WorkspaceStore.shared.documentStore.createResume(
            storagePath: WorkspaceStore.shared.projectStoragePath,
            slug: "existing-in-b",
            title: "Existing In B",
            paper: .a4,
            template: .classic
        )
        WorkspaceStore.shared.reload()
        #expect(WorkspaceStore.shared.projectResumes.map(\.id) == ["existing-in-b"])

        let tool = ConversationScopedResumeTool(CreateResumeTool())
        let context = conversationScopedContext(projectPath: projectA.path)
        _ = try await tool.executeResult(
            context: context,
            arguments: arguments([
                "slug": "created-in-a",
                "title": "Created In A",
                "paper": "a4",
                "template": "classic",
            ])
        )

        // UI 仍停在项目 B，面板内容不应被 A 的写入污染。
        #expect(WorkspaceStore.shared.projectResumes.map(\.id) == ["existing-in-b"])
        #expect(WorkspaceStore.shared.currentProjectPath == projectB.path)
    }

    @Test("未绑定项目的对话回退到 UI 当前打开项目")
    func unscopedConversationFallsBackToCurrentProject() async throws {
        let projectB = try makeScopedProjectRoot("b")
        defer { try? FileManager.default.removeItem(at: projectB) }

        ResumeDesignerRuntime.reset()
        let storageB = projectB
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent(ResumeDesignerRuntime.projectFolderName, isDirectory: true)
        ResumeDesignerRuntime.setProjectStorage(projectPath: projectB.path, projectStorageDirectory: storageB)

        let tool = ConversationScopedResumeTool(CreateResumeTool())
        // conversationProjectPathProvider 返回 nil —— 对话未绑定项目。
        let context = conversationScopedContext(projectPath: nil)
        _ = try await tool.executeResult(
            context: context,
            arguments: arguments([
                "slug": "fallback-resume",
                "title": "Fallback Resume",
                "paper": "a4",
                "template": "classic",
            ])
        )

        #expect(FileManager.default.fileExists(atPath: scopedManifestURL(project: projectB, slug: "fallback-resume").path))
    }

    @Test("对话绑定的项目路径无效时不会写进别的项目")
    func scopedConversationWithMissingProjectNeverWritesElsewhere() async throws {
        let projectB = try makeScopedProjectRoot("b")
        defer { try? FileManager.default.removeItem(at: projectB) }

        ResumeDesignerRuntime.reset()
        let storageB = projectB
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent(ResumeDesignerRuntime.projectFolderName, isDirectory: true)
        ResumeDesignerRuntime.setProjectStorage(projectPath: projectB.path, projectStorageDirectory: storageB)

        let tool = ConversationScopedResumeTool(CreateResumeTool())
        // 对话绑定了一个已不存在的项目（路径非空但磁盘上不存在）。
        let context = conversationScopedContext(projectPath: "/nonexistent/lumi/resume-scope")
        _ = try? await tool.executeResult(
            context: context,
            arguments: arguments([
                "slug": "ghost-resume",
                "title": "Ghost Resume",
                "paper": "a4",
                "template": "classic",
            ])
        )

        // 绝不落到项目 B。
        #expect(!FileManager.default.fileExists(atPath: scopedManifestURL(project: projectB, slug: "ghost-resume").path))
    }

    @Test("插件注册的 Agent 工具都带对话作用域包装")
    func registeredToolsAreConversationScoped() async throws {
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

        try kernel.start(plugins: [ResumeDesignerPlugin()])
        try await kernel.enablePlugin(id: ResumeDesignerPlugin().id)

        let registered = toolManager.allTools().filter { $0.name.hasPrefix("resume_") }
        #expect(registered.count == ResumeDesignerPlugin.agentTools.count)
        // 未包装的工具会退回「UI 当前打开项目」，多对话并行时串项目。
        #expect(registered.allSatisfy { $0 is ConversationScopedResumeTool })

        try kernel.stop()
        try? FileManager.default.removeItem(at: storage.dataRootDirectory)
    }
}
