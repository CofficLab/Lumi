import LumiKernel
import Foundation
import Testing
@testable import AppStorePromoDesignerPlugin

@MainActor
@Suite("App Store promo designer plugin")
struct PromoDesignerPluginTests {
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
            "app_store_promo_read_html",
            "app_store_promo_replace_html",
            "app_store_promo_patch_html",
            "app_store_promo_import_asset",
            "app_store_promo_preview_image",
            "app_store_promo_lint_task",
            "app_store_promo_export_task",
        ])
    }

    @Test func overwriteExportIsHighRisk() {
        let tool = ExportPromoTaskTool()
        let kernel = LumiKernel()
        #expect(tool.riskLevel(arguments: ["overwrite": .bool(false)], kernel: kernel) == .medium)
        #expect(tool.riskLevel(arguments: ["overwrite": .bool(true)], kernel: kernel) == .high)
    }

    @Test func agentToolsCreateTaskWithMultipleImagesAndPersistInPluginStorage() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let kernel = LumiKernel()
        Runtime.configure(persistenceDirectory: root)

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
        #expect(createTask.contains("Created App Store promotional artwork task"))

        let createImage = try await CreatePromoImageTool().execute(
            arguments: [
                "taskId": .string("launch-set"),
                "imageId": .string("agent-workflows"),
                "title": .string("Agent Workflows"),
            ],
            kernel: kernel
        )
        #expect(createImage.contains("Created promotional HTML image"))

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
}
