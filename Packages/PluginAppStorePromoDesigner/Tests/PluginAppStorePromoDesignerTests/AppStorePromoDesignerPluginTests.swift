import KitAgentTool
import Foundation
import KernelCore
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderRailView
import ProviderWorkspace
import Testing
@testable import PluginAppStorePromoDesigner

@MainActor
@Suite("App store promo designer plugin", .serialized)
struct AppStorePromoDesignerPluginTests {
    @Test func openingWithoutConfiguredStorageDoesNotShowAnError() {
        PromoDesignerRuntime.reset()
        WorkspaceStore.shared.reload()

        #expect(WorkspaceStore.shared.projectTasks.isEmpty)
        #expect(WorkspaceStore.shared.appTasks.isEmpty)
        #expect(WorkspaceStore.shared.lastError == nil)
    }

    @Test func contributesRailTabAndCompleteToolSet() {
        let plugin = AppStorePromoDesignerPlugin()
        #expect(plugin.id == "com.coffic.lumi.plugin.app-store-promo-designer")
        #expect(plugin.order == 80)
        #expect(AppStorePromoDesignerPlugin.railTabID == "app-store-promo.tasks")
        let names = Set(AppStorePromoDesignerPlugin.agentTools.map(\.name))
        #expect(names == [
            "app_store_promo_list_tasks",
            "app_store_promo_create_task",
            "app_store_promo_read_task",
            "app_store_promo_create_image",
            "app_store_promo_add_image_language",
            "app_store_promo_read_html",
            "app_store_promo_replace_html",
            "app_store_promo_patch_html",
            "app_store_promo_import_asset",
            "app_store_promo_preview_image",
            "app_store_promo_lint_task",
            "app_store_promo_export_task",
            "app_store_promo_review_image",
        ])
    }

    @Test func activatingPluginEntryShowsChatAndActivatesRail() async throws {
        let kernel = KernelCoreContainer()
        let activity = DefaultActivityBarProviding()
        let rail = DefaultRailViewProviding()
        let chat = DefaultChatSectionProviding()
        let workspace = DefaultWorkspaceProviding(
            pluginDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("PluginAppStorePromoDesignerWorkspaceTests-\(UUID().uuidString)")
        )

        try kernel.registerProvider((any ActivityBarProviding).self, activity)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any ContentViewProviding).self, DefaultContentViewProviding())
        try kernel.registerProvider((any RailViewProviding).self, rail)
        try kernel.registerProvider((any WorkspaceProviding).self, workspace)

        try kernel.start(plugins: [AppStorePromoDesignerPlugin()])
        try await kernel.enablePlugin(id: AppStorePromoDesignerPlugin().id)

        #expect(activity.activeItemID == "com.coffic.lumi.plugin.app-store-promo-designer.entry")
        #expect(rail.activeTabID == AppStorePromoDesignerPlugin.railTabID)
        #expect(workspace.activeContainerID == AppStorePromoDesignerPlugin().id)
        #expect(workspace.isChatVisible)
        #expect(chat.isVisible)
        #expect(chat.isContextActive)

        try kernel.stop()

        #expect(workspace.containers.isEmpty)
    }

    @Test func overwriteExportIsHighRisk() {
        let tool = ExportPromoTaskTool()
        #expect(tool.permissionRiskLevel(arguments: ["overwrite": ToolArgument(false)]) == .medium)
        #expect(tool.permissionRiskLevel(arguments: ["overwrite": ToolArgument(true)]) == .high)
    }

    @Test func agentToolsCreateTaskWithMultipleImagesAndPersistInAppStorage() async throws {
        PromoDesignerRuntime.reset()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        PromoDesignerRuntime.configure(appStorageDirectory: root)

        // 没有打开项目时,默认走 app scope。
        let createTask = try await CreatePromoTaskTool().execute(
            arguments: [
                "slug": ToolArgument("launch-set"),
                "title": ToolArgument("Launch Set"),
                "appName": ToolArgument("Lumi"),
                "deviceFamily": ToolArgument("mac"),
                "localeIdentifier": ToolArgument("en-US"),
            ]
        )
        #expect(createTask.contains("scope=app"))
        #expect(createTask.contains("Created App Store promotional artwork task"))

        let createImage = try await CreatePromoImageTool().execute(
            arguments: [
                "taskId": ToolArgument("launch-set"),
                "imageId": ToolArgument("agent-workflows"),
                "title": ToolArgument("Agent Workflows"),
            ]
        )
        #expect(createImage.contains("scope=app"))
        #expect(createImage.contains("Created promotional HTML image"))

        let addLanguage = try await AddPromoImageLocalizationTool().execute(
            arguments: [
                "taskId": ToolArgument("launch-set"),
                "imageId": ToolArgument("agent-workflows"),
                "localeIdentifier": ToolArgument("zh-Hans"),
            ]
        )
        #expect(addLanguage.contains("locale=zh-Hans"))

        let localizedHTML = try await ReadPromoHTMLTool().execute(
            arguments: [
                "taskId": ToolArgument("launch-set"),
                "imageId": ToolArgument("agent-workflows"),
                "localeIdentifier": ToolArgument("zh-Hans"),
            ]
        )
        #expect(localizedHTML.contains("localeIdentifier=zh-Hans"))

        _ = try await CreatePromoImageTool().execute(
            arguments: [
                "taskId": ToolArgument("launch-set"),
                "imageId": ToolArgument("private-data"),
                "title": ToolArgument("Private Data"),
            ]
        )

        let patched = try await PatchPromoHTMLTool().execute(
            arguments: [
                "taskId": ToolArgument("launch-set"),
                "imageId": ToolArgument("agent-workflows"),
                "operations": ToolArgument([
                    ["oldText": "<h1>Agent Workflows</h1>", "newText": "<h1>Build visually</h1>"],
                ]),
            ]
        )
        #expect(patched.contains("Applied 1 HTML patches"))

        let read = try await ReadPromoHTMLTool().execute(
            arguments: [
                "taskId": ToolArgument("launch-set"),
                "imageId": ToolArgument("agent-workflows"),
            ]
        )
        #expect(read.contains("<h1>Build visually</h1>"))

        let lint = try await LintPromoTaskTool().execute(
            arguments: ["taskId": ToolArgument("launch-set")]
        )
        #expect(lint.contains("PASS"))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("tasks/launch-set/images/agent-workflows/index.html").path))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("tasks/launch-set/images/private-data/index.html").path))
    }

    @Test func explicitScopeRoutesWriteAndReadOperations() async throws {
        PromoDesignerRuntime.reset()
        let appRoot = FileManager.default.temporaryDirectory.appendingPathComponent("app-\(UUID().uuidString)", isDirectory: true)
        let projectRoot = FileManager.default.temporaryDirectory.appendingPathComponent("project-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: appRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: appRoot)
            try? FileManager.default.removeItem(at: projectRoot)
        }
        PromoDesignerRuntime.configure(appStorageDirectory: appRoot)
        PromoDesignerRuntime.setProjectStorage(projectPath: projectRoot.path, projectStorageDirectory: projectRoot)

        // 显式 app scope。
        let appCreate = try await CreatePromoTaskTool().execute(
            arguments: [
                "slug": ToolArgument("app-only-set"),
                "title": ToolArgument("App Only Set"),
                "appName": ToolArgument("Lumi"),
                "deviceFamily": ToolArgument("iphone"),
                "scope": ToolArgument("app"),
            ]
        )
        #expect(appCreate.contains("scope=app"))

        // 显式 project scope。
        let projectCreate = try await CreatePromoTaskTool().execute(
            arguments: [
                "slug": ToolArgument("project-only-set"),
                "title": ToolArgument("Project Only Set"),
                "appName": ToolArgument("Lumi"),
                "deviceFamily": ToolArgument("mac"),
                "scope": ToolArgument("project"),
            ]
        )
        #expect(projectCreate.contains("scope=project"))

        // 文件系统隔离:每个 scope 各自存储。
        #expect(FileManager.default.fileExists(atPath: appRoot.appendingPathComponent("tasks/app-only-set/manifest.json").path))
        #expect(FileManager.default.fileExists(atPath: projectRoot.appendingPathComponent("tasks/project-only-set/manifest.json").path))
        #expect(FileManager.default.fileExists(atPath: appRoot.appendingPathComponent("tasks/project-only-set/manifest.json").path) == false)
        #expect(FileManager.default.fileExists(atPath: projectRoot.appendingPathComponent("tasks/app-only-set/manifest.json").path) == false)

        // list_tasks 默认返回两个 scope 并打标。
        let listAll = try await ListPromoTasksTool().execute(arguments: [:])
        #expect(listAll.contains("scope=app"))
        #expect(listAll.contains("scope=project"))

        // list_tasks scope=project 只返回项目内的任务。
        let listProject = try await ListPromoTasksTool().execute(arguments: ["scope": ToolArgument("project")])
        #expect(listProject.contains("scope=project"))
        #expect(listProject.contains("project-only-set"))
        #expect(!listProject.contains("app-only-set"))

        // list_tasks scope=app 只返回 app 内的任务。
        let listApp = try await ListPromoTasksTool().execute(arguments: ["scope": ToolArgument("app")])
        #expect(listApp.contains("scope=app"))
        #expect(listApp.contains("app-only-set"))
        #expect(!listApp.contains("project-only-set"))

        // read_task 显式 scope=project 只在项目内查找。
        let readProject = try await ReadPromoTaskTool().execute(
            arguments: ["taskId": ToolArgument("project-only-set"), "scope": ToolArgument("project")]
        )
        #expect(readProject.contains("scope=project"))
        #expect(readProject.contains("project-only-set"))

        // read_task 显式 scope=app 找 app 内 task。
        let readApp = try await ReadPromoTaskTool().execute(
            arguments: ["taskId": ToolArgument("app-only-set"), "scope": ToolArgument("app")]
        )
        #expect(readApp.contains("scope=app"))
        #expect(readApp.contains("app-only-set"))

        // 无 scope 时,read_task 默认 scope=project(优先在项目内找)。
        let readDefault = try await ReadPromoTaskTool().execute(
            arguments: ["taskId": ToolArgument("project-only-set")]
        )
        #expect(readDefault.contains("scope=project"))
    }

    @Test func scopeFallsBackToAppWhenProjectMissing() async throws {
        PromoDesignerRuntime.reset()
        let appRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: appRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: appRoot) }
        PromoDesignerRuntime.configure(appStorageDirectory: appRoot)
        // 不调用 setProjectStorage,模拟无打开项目。

        let create = try await CreatePromoTaskTool().execute(
            arguments: [
                "slug": ToolArgument("default-fallback"),
                "title": ToolArgument("Default Fallback"),
                "appName": ToolArgument("Lumi"),
                "deviceFamily": ToolArgument("ipad"),
            ]
        )
        // 无项目时,默认 scope 应回退到 app。
        #expect(create.contains("scope=app"))
        #expect(FileManager.default.fileExists(atPath: appRoot.appendingPathComponent("tasks/default-fallback/manifest.json").path))
    }
}
