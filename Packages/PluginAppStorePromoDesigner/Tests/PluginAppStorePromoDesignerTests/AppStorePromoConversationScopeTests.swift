import KitAgentTool
import KitAppStorePromo
import Foundation
import Testing
@testable import PluginAppStorePromoDesigner

/// 复现「多对话并行时，工具把数据写进另一个对话的项目」。
///
/// 场景：对话 A 绑定项目 A，Agent 正在执行工具；此时用户切到对话 B，
/// 内核把「当前打开项目」切到 B。旧实现从 `WorkspaceStore.shared`
/// （跟随 UI 当前项目）取路径，于是 A 的工具调用写进了 B。
///
/// 这些用例会改动全局 `WorkspaceStore.shared`，因此以扩展形式并入
/// 插件主测试套件（已标记 `.serialized`），与其他改动同一全局状态的
/// 用例串行执行，避免并行时互相污染。
extension AppStorePromoDesignerPluginTests {
    /// 构造一个临时项目根目录。
    private func makeScopedProjectRoot(_ name: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("promo-scope-\(name)-\(UUID().uuidString)", isDirectory: true)
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

    /// 某项目下任务 manifest 的路径。
    private func scopedManifestURL(project: URL, slug: String) -> URL {
        project
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent(PromoDesignerRuntime.projectFolderName, isDirectory: true)
            .appendingPathComponent("tasks", isDirectory: true)
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
        PromoDesignerRuntime.reset()
        let storageB = projectB
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent(PromoDesignerRuntime.projectFolderName, isDirectory: true)
        PromoDesignerRuntime.setProjectStorage(projectPath: projectB.path, projectStorageDirectory: storageB)

        // 但本次工具调用属于对话 A，其项目是 A。
        let tool = ConversationScopedPromoTool(CreatePromoTaskTool())
        let context = conversationScopedContext(projectPath: projectA.path)

        let result = try await tool.executeResult(
            context: context,
            arguments: [
                "slug": ToolArgument("scoped-task"),
                "title": ToolArgument("Scoped Task"),
                "appName": ToolArgument("Lumi"),
                "deviceFamily": ToolArgument("mac"),
            ]
        )
        #expect(result.content.contains("Created App Store promotional artwork task"))

        // 期望：写入项目 A 的 .lumi/app-store-promo。
        #expect(FileManager.default.fileExists(atPath: scopedManifestURL(project: projectA, slug: "scoped-task").path))

        // 失败症状：数据落到了项目 B。
        #expect(!FileManager.default.fileExists(atPath: scopedManifestURL(project: projectB, slug: "scoped-task").path))
    }

    @Test("对话 A 的工具读取只看到项目 A 的任务")
    func conversationScopedToolReadsFromItsOwnProject() async throws {
        let projectA = try makeScopedProjectRoot("a")
        let projectB = try makeScopedProjectRoot("b")
        defer {
            try? FileManager.default.removeItem(at: projectA)
            try? FileManager.default.removeItem(at: projectB)
        }

        PromoDesignerRuntime.reset()
        let storageB = projectB
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent(PromoDesignerRuntime.projectFolderName, isDirectory: true)
        PromoDesignerRuntime.setProjectStorage(projectPath: projectB.path, projectStorageDirectory: storageB)

        // 项目 A 与项目 B 各有一个任务。
        let store = AppStorePromoDocumentStore()
        _ = try store.createTask(
            storagePath: PromoDesignerRuntime.promoStorageDirectory(forProjectPath: projectA.path)!.path,
            slug: "only-in-a",
            title: "Only In A",
            appName: "Lumi",
            deviceFamily: .mac,
            localeIdentifier: "en-US"
        )
        _ = try store.createTask(
            storagePath: PromoDesignerRuntime.promoStorageDirectory(forProjectPath: projectB.path)!.path,
            slug: "only-in-b",
            title: "Only In B",
            appName: "Lumi",
            deviceFamily: .mac,
            localeIdentifier: "en-US"
        )

        let tool = ConversationScopedPromoTool(ListPromoTasksTool())
        let context = conversationScopedContext(projectPath: projectA.path)
        let result = try await tool.executeResult(context: context, arguments: [:])

        // 列表必须只包含项目 A 的任务。
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

        PromoDesignerRuntime.reset()
        let storageB = projectB
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent(PromoDesignerRuntime.projectFolderName, isDirectory: true)
        PromoDesignerRuntime.setProjectStorage(projectPath: projectB.path, projectStorageDirectory: storageB)

        // 让 UI 当前项目（B）里已有一个任务，作为「面板已有内容」的基线。
        _ = try WorkspaceStore.shared.documentStore.createTask(
            storagePath: WorkspaceStore.shared.projectStoragePath,
            slug: "existing-in-b",
            title: "Existing In B",
            appName: "Lumi",
            deviceFamily: .mac,
            localeIdentifier: "en-US"
        )
        WorkspaceStore.shared.reload()
        #expect(WorkspaceStore.shared.projectTasks.map(\.id) == ["existing-in-b"])

        let tool = ConversationScopedPromoTool(CreatePromoTaskTool())
        let context = conversationScopedContext(projectPath: projectA.path)
        _ = try await tool.executeResult(
            context: context,
            arguments: [
                "slug": ToolArgument("created-in-a"),
                "title": ToolArgument("Created In A"),
                "appName": ToolArgument("Lumi"),
                "deviceFamily": ToolArgument("mac"),
            ]
        )

        // UI 仍停在项目 B，面板内容不应被 A 的写入污染。
        #expect(WorkspaceStore.shared.projectTasks.map(\.id) == ["existing-in-b"])
        #expect(WorkspaceStore.shared.currentProjectPath == projectB.path)
    }

    @Test("未绑定项目的对话回退到 UI 当前打开项目")
    func unscopedConversationFallsBackToCurrentProject() async throws {
        let projectB = try makeScopedProjectRoot("b")
        defer { try? FileManager.default.removeItem(at: projectB) }

        PromoDesignerRuntime.reset()
        let storageB = projectB
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent(PromoDesignerRuntime.projectFolderName, isDirectory: true)
        PromoDesignerRuntime.setProjectStorage(projectPath: projectB.path, projectStorageDirectory: storageB)

        let tool = ConversationScopedPromoTool(CreatePromoTaskTool())
        // conversationProjectPathProvider 返回 nil —— 对话未绑定项目。
        let context = conversationScopedContext(projectPath: nil)
        _ = try await tool.executeResult(
            context: context,
            arguments: [
                "slug": ToolArgument("fallback-task"),
                "title": ToolArgument("Fallback Task"),
                "appName": ToolArgument("Lumi"),
                "deviceFamily": ToolArgument("mac"),
            ]
        )

        #expect(FileManager.default.fileExists(atPath: scopedManifestURL(project: projectB, slug: "fallback-task").path))
    }

    @Test("对话绑定的项目路径无效时不会写进别的项目")
    func scopedConversationWithMissingProjectNeverWritesElsewhere() async throws {
        let projectB = try makeScopedProjectRoot("b")
        defer { try? FileManager.default.removeItem(at: projectB) }

        PromoDesignerRuntime.reset()
        let storageB = projectB
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent(PromoDesignerRuntime.projectFolderName, isDirectory: true)
        PromoDesignerRuntime.setProjectStorage(projectPath: projectB.path, projectStorageDirectory: storageB)

        let tool = ConversationScopedPromoTool(CreatePromoTaskTool())
        // 对话绑定了一个已不存在的项目（路径非空但磁盘上不存在）。
        let context = conversationScopedContext(projectPath: "/nonexistent/lumi/promo-scope")
        _ = try? await tool.executeResult(
            context: context,
            arguments: [
                "slug": ToolArgument("ghost-task"),
                "title": ToolArgument("Ghost Task"),
                "appName": ToolArgument("Lumi"),
                "deviceFamily": ToolArgument("mac"),
            ]
        )

        // 绝不落到项目 B。
        #expect(!FileManager.default.fileExists(atPath: scopedManifestURL(project: projectB, slug: "ghost-task").path))
    }
}
