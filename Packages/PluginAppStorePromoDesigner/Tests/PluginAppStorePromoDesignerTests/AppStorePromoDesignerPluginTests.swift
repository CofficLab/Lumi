import KitAgentTool
import Foundation
import KernelCore
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderRailView
import ProviderRootView
import ProviderToolbar
import Testing
@testable import PluginAppStorePromoDesigner

@MainActor
@Suite("App store promo designer plugin", .serialized)
struct AppStorePromoDesignerPluginTests {
    @Test func openingWithoutConfiguredStorageDoesNotShowAnError() {
        PromoDesignerRuntime.reset()
        WorkspaceStore.shared.reload()

        #expect(WorkspaceStore.shared.projectTasks.isEmpty)
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

    @Test("提示词标题本地化 key 可解析")
    func promptSuggestionLocalizationResolves() {
        let key = "Prompt.Suggestion.Create"
        #expect(PromoLocalization.string(key) != key)
        let noSelectionKey = "Select a task from the left, or ask the Agent to create a promotional artwork task."
        #expect(PromoLocalization.string(noSelectionKey) != noSelectionKey)
    }

    @Test func activatingPluginEntryShowsChatAndActivatesRail() async throws {
        PromoDesignerRuntime.reset()
        let kernel = KernelCoreContainer()
        let activity = DefaultActivityBarProviding()
        let rail = DefaultRailViewProviding()
        let chat = DefaultChatSectionProviding()
        let rootView = DefaultRootViewProvider()
        let toolbar = DefaultToolbarProviding()

        try kernel.registerProvider((any ActivityBarProviding).self, activity)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        try kernel.registerProvider((any ContentViewProviding).self, DefaultContentViewProviding())
        try kernel.registerProvider((any RailViewProviding).self, rail)
        try kernel.registerProvider((any RootViewProviding).self, rootView)
        try kernel.registerProvider((any ToolbarProviding).self, toolbar)

        try kernel.start(plugins: [AppStorePromoDesignerPlugin()])
        try await kernel.enablePlugin(id: AppStorePromoDesignerPlugin().id)

        #expect(activity.activeItemID == "com.coffic.lumi.plugin.app-store-promo-designer.entry")
        #expect(rail.activeTabID == AppStorePromoDesignerPlugin.railTabID)
        #expect(chat.isVisible)
        #expect(chat.isContextActive)
        #expect(rootView.isContentHeaderViewHidden)
        #expect(!rootView.isRailViewVisible)
        #expect(toolbar.visibleCategories == [.global, .project, .chat, .design])

        try kernel.stop()

        #expect(rootView.isContentHeaderViewHidden == false)
        #expect(rootView.isRailViewVisible == rail.hasVisibleTabs)
    }

    @Test func overwriteExportIsHighRisk() {
        let tool = ExportPromoTaskTool()
        #expect(tool.permissionRiskLevel(arguments: ["overwrite": ToolArgument(false)]) == .medium)
        #expect(tool.permissionRiskLevel(arguments: ["overwrite": ToolArgument(true)]) == .high)
    }

    @Test func agentToolsCreateTaskWithMultipleImagesAndPersistInProjectStorage() async throws {
        PromoDesignerRuntime.reset()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        PromoDesignerRuntime.setProjectStorage(projectPath: root.path, projectStorageDirectory: root)

        let createTask = try await CreatePromoTaskTool().execute(
            arguments: [
                "slug": ToolArgument("launch-set"),
                "title": ToolArgument("Launch Set"),
                "appName": ToolArgument("Lumi"),
                "deviceFamily": ToolArgument("mac"),
                "localeIdentifier": ToolArgument("en-US"),
            ]
        )
        #expect(createTask.contains("Created App Store promotional artwork task"))

        let createImage = try await CreatePromoImageTool().execute(
            arguments: [
                "taskId": ToolArgument("launch-set"),
                "imageId": ToolArgument("agent-workflows"),
                "title": ToolArgument("Agent Workflows"),
            ]
        )
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

    @Test func agentToolsUseOnlyProjectStorage() async throws {
        PromoDesignerRuntime.reset()
        let projectRoot = FileManager.default.temporaryDirectory.appendingPathComponent("project-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: projectRoot)
        }
        PromoDesignerRuntime.setProjectStorage(projectPath: projectRoot.path, projectStorageDirectory: projectRoot)

        let projectCreate = try await CreatePromoTaskTool().execute(
            arguments: [
                "slug": ToolArgument("project-only-set"),
                "title": ToolArgument("Project Only Set"),
                "appName": ToolArgument("Lumi"),
                "deviceFamily": ToolArgument("mac"),
            ]
        )
        #expect(projectCreate.contains("project-only-set"))

        #expect(FileManager.default.fileExists(atPath: projectRoot.appendingPathComponent("tasks/project-only-set/manifest.json").path))

        let listProject = try await ListPromoTasksTool().execute(arguments: [:])
        #expect(listProject.contains("project-only-set"))

        let readProject = try await ReadPromoTaskTool().execute(
            arguments: ["taskId": ToolArgument("project-only-set")]
        )
        #expect(readProject.contains("project-only-set"))
    }

    @Test func toolsRequireAnOpenProject() async throws {
        PromoDesignerRuntime.reset()
        var didThrow = false
        do {
            _ = try await CreatePromoTaskTool().execute(
                arguments: [
                    "slug": ToolArgument("requires-project"),
                    "title": ToolArgument("Requires Project"),
                    "appName": ToolArgument("Lumi"),
                    "deviceFamily": ToolArgument("ipad"),
                ]
            )
        } catch {
            didThrow = true
        }
        #expect(didThrow)
    }
}
