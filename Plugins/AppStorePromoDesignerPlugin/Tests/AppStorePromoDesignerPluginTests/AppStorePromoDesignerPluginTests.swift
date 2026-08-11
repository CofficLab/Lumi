import LumiKernel
import Foundation
import Testing
@testable import AppStorePromoDesignerPlugin

@MainActor
@Suite("App Store promo designer plugin", .serialized)
struct PromoDesignerPluginTests {
    @Test func openingWithoutConfiguredStorageDoesNotShowAnError() {
        Runtime.reset()
        WorkspaceStore.shared.reload()

        #expect(WorkspaceStore.shared.projectTasks.isEmpty)
        #expect(WorkspaceStore.shared.appTasks.isEmpty)
        #expect(WorkspaceStore.shared.lastError == nil)
    }

    @Test func contributesOptInWorkspaceAndCompleteToolSet() {
        let plugin = PromoDesignerPlugin()
        let kernel = LumiKernel()
        #expect(plugin.id == "com.coffic.lumi.plugin.app-store-promo-designer")
        #expect(plugin.policy == .optIn)
        #expect(plugin.viewContainers(kernel: kernel).count == 1)
        #expect(plugin.panelRailTabItems(kernel: kernel).count == 1)
        let names = Set(plugin.agentTools(kernel: kernel).map(\.name))
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

    @Test func overwriteExportIsHighRisk() {
        let tool = ExportPromoTaskTool()
        let kernel = LumiKernel()
        #expect(tool.riskLevel(arguments: ["overwrite": .bool(false)], kernel: kernel) == .medium)
        #expect(tool.riskLevel(arguments: ["overwrite": .bool(true)], kernel: kernel) == .high)
    }

    @Test func agentToolsCreateTaskWithMultipleImagesAndPersistInAppStorage() async throws {
        Runtime.reset()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let kernel = LumiKernel()
        Runtime.configure(appStorageDirectory: root)

        // 没有打开项目时,默认走 app scope。
        let createTask = try await CreatePromoTaskTool().execute(
            arguments: [
                "slug": .string("launch-set"),
                "title": .string("Launch Set"),
                "appName": .string("Lumi"),
                "deviceFamily": .string("mac"),
                "localeIdentifier": .string("en-US"),
            ],
            kernel: kernel
        )
        #expect(createTask.contains("scope=app"))
        #expect(createTask.contains("Created App Store promotional artwork task"))

        let createImage = try await CreatePromoImageTool().execute(
            arguments: [
                "taskId": .string("launch-set"),
                "imageId": .string("agent-workflows"),
                "title": .string("Agent Workflows"),
            ],
            kernel: kernel
        )
        #expect(createImage.contains("scope=app"))
        #expect(createImage.contains("Created promotional HTML image"))

        let addLanguage = try await AddPromoImageLocalizationTool().execute(
            arguments: [
                "taskId": .string("launch-set"),
                "imageId": .string("agent-workflows"),
                "localeIdentifier": .string("zh-Hans"),
            ],
            kernel: kernel
        )
        #expect(addLanguage.contains("locale=zh-Hans"))

        let localizedHTML = try await ReadPromoHTMLTool().execute(
            arguments: [
                "taskId": .string("launch-set"),
                "imageId": .string("agent-workflows"),
                "localeIdentifier": .string("zh-Hans"),
            ],
            kernel: kernel
        )
        #expect(localizedHTML.contains("localeIdentifier=zh-Hans"))

        _ = try await CreatePromoImageTool().execute(
            arguments: [
                "taskId": .string("launch-set"),
                "imageId": .string("private-data"),
                "title": .string("Private Data"),
            ],
            kernel: kernel
        )

        let patched = try await PatchPromoHTMLTool().execute(
            arguments: [
                "taskId": .string("launch-set"),
                "imageId": .string("agent-workflows"),
                "operations": .array([
                    .object([
                        "oldText": .string("<h1>Agent Workflows</h1>"),
                        "newText": .string("<h1>Build visually</h1>"),
                    ]),
                ]),
            ],
            kernel: kernel
        )
        #expect(patched.contains("Applied 1 HTML patches"))

        let read = try await ReadPromoHTMLTool().execute(
            arguments: [
                "taskId": .string("launch-set"),
                "imageId": .string("agent-workflows"),
            ],
            kernel: kernel
        )
        #expect(read.contains("<h1>Build visually</h1>"))

        let lint = try await LintPromoTaskTool().execute(
            arguments: ["taskId": .string("launch-set")],
            kernel: kernel
        )
        #expect(lint.contains("PASS"))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("tasks/launch-set/images/agent-workflows/index.html").path))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("tasks/launch-set/images/private-data/index.html").path))
    }

    @Test func explicitScopeRoutesWriteAndReadOperations() async throws {
        Runtime.reset()
        let appRoot = FileManager.default.temporaryDirectory.appendingPathComponent("app-\(UUID().uuidString)", isDirectory: true)
        let projectRoot = FileManager.default.temporaryDirectory.appendingPathComponent("project-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: appRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: appRoot)
            try? FileManager.default.removeItem(at: projectRoot)
        }
        let kernel = LumiKernel()
        Runtime.configure(appStorageDirectory: appRoot)
        Runtime.setProjectStorage(projectPath: projectRoot.path, projectStorageDirectory: projectRoot)

        // 显式 app scope。
        let appCreate = try await CreatePromoTaskTool().execute(
            arguments: [
                "slug": .string("app-only-set"),
                "title": .string("App Only Set"),
                "appName": .string("Lumi"),
                "deviceFamily": .string("iphone"),
                "scope": .string("app"),
            ],
            kernel: kernel
        )
        #expect(appCreate.contains("scope=app"))

        // 显式 project scope。
        let projectCreate = try await CreatePromoTaskTool().execute(
            arguments: [
                "slug": .string("project-only-set"),
                "title": .string("Project Only Set"),
                "appName": .string("Lumi"),
                "deviceFamily": .string("mac"),
                "scope": .string("project"),
            ],
            kernel: kernel
        )
        #expect(projectCreate.contains("scope=project"))

        // 文件系统隔离:每个 scope 各自存储。
        #expect(FileManager.default.fileExists(atPath: appRoot.appendingPathComponent("tasks/app-only-set/manifest.json").path))
        #expect(FileManager.default.fileExists(atPath: projectRoot.appendingPathComponent("tasks/project-only-set/manifest.json").path))
        #expect(FileManager.default.fileExists(atPath: appRoot.appendingPathComponent("tasks/project-only-set/manifest.json").path) == false)
        #expect(FileManager.default.fileExists(atPath: projectRoot.appendingPathComponent("tasks/app-only-set/manifest.json").path) == false)

        // list_tasks 默认返回两个 scope 并打标。
        let listAll = try await ListPromoTasksTool().execute(arguments: [:], kernel: kernel)
        #expect(listAll.contains("scope=app"))
        #expect(listAll.contains("scope=project"))

        // list_tasks scope=project 只返回项目内的任务。
        let listProject = try await ListPromoTasksTool().execute(arguments: ["scope": .string("project")], kernel: kernel)
        #expect(listProject.contains("scope=project"))
        #expect(listProject.contains("project-only-set"))
        #expect(!listProject.contains("app-only-set"))

        // list_tasks scope=app 只返回 app 内的任务。
        let listApp = try await ListPromoTasksTool().execute(arguments: ["scope": .string("app")], kernel: kernel)
        #expect(listApp.contains("scope=app"))
        #expect(listApp.contains("app-only-set"))
        #expect(!listApp.contains("project-only-set"))

        // read_task 显式 scope=project 只在项目内查找。
        let readProject = try await ReadPromoTaskTool().execute(
            arguments: ["taskId": .string("project-only-set"), "scope": .string("project")],
            kernel: kernel
        )
        #expect(readProject.contains("scope=project"))
        #expect(readProject.contains("project-only-set"))

        // read_task 显式 scope=app 找 app 内 task。
        let readApp = try await ReadPromoTaskTool().execute(
            arguments: ["taskId": .string("app-only-set"), "scope": .string("app")],
            kernel: kernel
        )
        #expect(readApp.contains("scope=app"))
        #expect(readApp.contains("app-only-set"))

        // 无 scope 时,read_task 默认 scope=project(优先在项目内找)。
        let readDefault = try await ReadPromoTaskTool().execute(
            arguments: ["taskId": .string("project-only-set")],
            kernel: kernel
        )
        #expect(readDefault.contains("scope=project"))
    }

    @Test func scopeFallsBackToAppWhenProjectMissing() async throws {
        Runtime.reset()
        let appRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: appRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: appRoot) }
        let kernel = LumiKernel()
        Runtime.configure(appStorageDirectory: appRoot)
        // 不调用 setProjectStorage,模拟无打开项目。

        let create = try await CreatePromoTaskTool().execute(
            arguments: [
                "slug": .string("default-fallback"),
                "title": .string("Default Fallback"),
                "appName": .string("Lumi"),
                "deviceFamily": .string("ipad"),
            ],
            kernel: kernel
        )
        // 无项目时,默认 scope 应回退到 app。
        #expect(create.contains("scope=app"))
        #expect(FileManager.default.fileExists(atPath: appRoot.appendingPathComponent("tasks/default-fallback/manifest.json").path))
    }
}
