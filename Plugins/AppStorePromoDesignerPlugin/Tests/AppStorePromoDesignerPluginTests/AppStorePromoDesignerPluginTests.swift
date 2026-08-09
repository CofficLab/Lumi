import LumiKernel
import Foundation
import Testing
@testable import AppStorePromoDesignerPlugin

@MainActor
@Suite("App Store promo designer plugin")
struct AppStorePromoDesignerPluginTests {
    @Test func contributesOptInWorkspaceAndCompleteToolSet() {
        let plugin = AppStorePromoDesignerPlugin()
        let kernel = LumiKernel()
        #expect(plugin.id == "com.coffic.lumi.plugin.app-store-promo-designer")
        #expect(plugin.policy == .optIn)
        #expect(plugin.viewContainers(kernel: kernel).count == 1)
        #expect(plugin.panelRailTabItems(kernel: kernel).count == 1)
        let names = Set(plugin.agentTools(kernel: kernel).map(\.name))
        #expect(names == [
            "app_store_promo_list_projects",
            "app_store_promo_create_project",
            "app_store_promo_read_project",
            "app_store_promo_create_page",
            "app_store_promo_read_html",
            "app_store_promo_replace_html",
            "app_store_promo_patch_html",
            "app_store_promo_import_asset",
            "app_store_promo_preview_page",
            "app_store_promo_lint_project",
            "app_store_promo_export_project",
        ])
    }

    @Test func overwriteExportIsHighRisk() {
        let tool = ExportAppStorePromoProjectTool()
        let kernel = LumiKernel()
        #expect(tool.riskLevel(arguments: ["overwrite": .bool(false)], kernel: kernel) == .medium)
        #expect(tool.riskLevel(arguments: ["overwrite": .bool(true)], kernel: kernel) == .high)
    }

    @Test func agentToolsCreateReadPatchAndLintHTMLProject() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let kernel = LumiKernel()
        let projectPath = LumiJSONValue.string(root.path)

        let createProject = try await CreateAppStorePromoProjectTool().execute(
            arguments: [
                "projectPath": projectPath,
                "slug": .string("launch-set"),
                "title": .string("Launch Set"),
                "appName": .string("Lumi"),
                "deviceFamily": .string("mac"),
                "localeIdentifier": .string("en-US"),
            ],
            kernel: kernel
        )
        #expect(createProject.contains("Created App Store promotional project"))

        let createPage = try await CreateAppStorePromoPageTool().execute(
            arguments: [
                "projectPath": projectPath,
                "projectId": .string("launch-set"),
                "pageId": .string("agent-workflows"),
                "title": .string("Agent Workflows"),
            ],
            kernel: kernel
        )
        #expect(createPage.contains("htmlPath="))

        let patched = try await PatchAppStorePromoHTMLTool().execute(
            arguments: [
                "projectPath": projectPath,
                "projectId": .string("launch-set"),
                "pageId": .string("agent-workflows"),
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

        let read = try await ReadAppStorePromoHTMLTool().execute(
            arguments: [
                "projectPath": projectPath,
                "projectId": .string("launch-set"),
                "pageId": .string("agent-workflows"),
            ],
            kernel: kernel
        )
        #expect(read.contains("<h1>Build visually</h1>"))

        let lint = try await LintAppStorePromoProjectTool().execute(
            arguments: ["projectPath": projectPath, "projectId": .string("launch-set")],
            kernel: kernel
        )
        #expect(lint.contains("PASS"))
    }
}
