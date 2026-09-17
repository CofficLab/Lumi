import AppKit
import CoreGraphics
import Foundation
import KernelCore
import KitAgentTool
import KitPrototype
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderRailView
import ProviderRootView
import ProviderToolbar
import Testing
@testable import PluginPrototypeDesigner

@MainActor
@Suite("Prototype designer plugin", .serialized)
struct PrototypeDesignerPluginTests {

    // MARK: - 插件契约

    @Test func pluginMetadataMatchesContract() {
        let plugin = PrototypeDesignerPlugin()
        #expect(plugin.id == "com.coffic.lumi.plugin.prototype-designer")
        #expect(plugin.order == 82)
        #expect(PrototypeDesignerPlugin.railTabID == "prototype.screens")
        #expect(plugin.metadata.category == .design)
        #expect(plugin.metadata.policy == .disabledByDefault)
    }

    @Test func contributesCompleteUniqueToolSet() {
        let names = PrototypeDesignerPlugin.agentTools.map(\.name)
        #expect(Set(names).count == names.count, "tool names must be unique")
        #expect(Set(names) == [
            "prototype_list_projects",
            "prototype_create_project",
            "prototype_read_project",
            "prototype_update_project",
            "prototype_delete_project",
            "prototype_add_screen",
            "prototype_duplicate_screen",
            "prototype_delete_screen",
            "prototype_reorder_screens",
            "prototype_set_start_screen",
            "prototype_read_html",
            "prototype_replace_html",
            "prototype_patch_html",
            "prototype_preview_screen",
            "prototype_import_asset",
            "prototype_lint",
            "prototype_export",
        ])
    }

    @Test func everyToolAdvertisesAValidSchemaAndDescription() {
        for tool in PrototypeDesignerPlugin.agentTools {
            let schema = tool.inputSchema(for: .english)
            #expect(schema["type"] as? String == "object", "\(tool.name) must declare an object schema")
            #expect(schema["properties"] != nil, "\(tool.name) must declare properties")
            #expect(!tool.description(for: .english).isEmpty, "\(tool.name) must describe itself")
            #expect(!tool.displayDescription(for: [:]).isEmpty, "\(tool.name) must have a display description")
            #expect(!tool.description(for: .chinese).isEmpty, "\(tool.name) must have a Chinese description")
        }
    }

    @Test func destructiveToolsAreHighRisk() {
        #expect(DeletePrototypeProjectTool().permissionRiskLevel(arguments: [:]) == .high)
        #expect(DeletePrototypeScreenTool().permissionRiskLevel(arguments: [:]) == .high)
        #expect(PreviewPrototypeScreenTool().permissionRiskLevel(arguments: [:]) == .low)
        #expect(LintPrototypeTool().permissionRiskLevel(arguments: [:]) == .low)
    }

    @Test func exportEscalatesRiskWhenOverwriting() {
        let tool = ExportPrototypeTool()
        #expect(tool.permissionRiskLevel(arguments: ["overwrite": ToolArgument(false)]) == .medium)
        #expect(tool.permissionRiskLevel(arguments: ["overwrite": ToolArgument(true)]) == .high)
    }

    @Test("提示词标题本地化 key 可解析")
    func promptSuggestionLocalizationResolves() {
        #expect(PrototypeLocalization.string("Prompt.Suggestion.Create") != "Prompt.Suggestion.Create")
        #expect(PrototypeLocalization.string("Prototype Designer") != "Prototype Designer")
    }

    // MARK: - 设备参数解析

    @Test func deviceParsingUsesPresetAndOverrides() throws {
        let preset = try PrototypeToolSupport.device(from: ["deviceKind": ToolArgument("iPhone15Pro")])
        #expect(preset.width == 393)
        #expect(preset.pixelWidth == 1179)

        let overridden = try PrototypeToolSupport.device(from: [
            "deviceKind": ToolArgument("desktop"),
            "deviceScale": ToolArgument(1.0),
        ])
        #expect(overridden.kind == .desktop)
        #expect(overridden.pixelWidth == 1440)

        let custom = try PrototypeToolSupport.device(from: [
            "deviceKind": ToolArgument("custom"),
            "deviceWidth": ToolArgument(500.0),
            "deviceHeight": ToolArgument(800.0),
            "deviceScale": ToolArgument(2.0),
        ])
        #expect(custom.kind == .custom)
        #expect(custom.pixelWidth == 1000)
        #expect(custom.pixelHeight == 1600)
    }

    @Test func deviceParsingRejectsInvalidInput() {
        #expect(throws: (any Error).self) {
            _ = try PrototypeToolSupport.device(from: ["deviceKind": ToolArgument("nope")])
        }
        #expect(throws: (any Error).self) {
            _ = try PrototypeToolSupport.device(from: ["deviceKind": ToolArgument("custom")])
        }
    }

    // MARK: - Runtime 存储

    @Test func runtimeUsesProjectScopedPrototypeDirectory() throws {
        PrototypeDesignerRuntime.reset()
        let projectRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("prototype-plugin-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: projectRoot) }

        PrototypeDesignerRuntime.setProjectStorage(
            projectPath: projectRoot.path,
            projectStorageDirectory: projectRoot.appendingPathComponent("prototype", isDirectory: true)
        )
        #expect(PrototypeDesignerRuntime.currentProjectPath == projectRoot.path)
        #expect(WorkspaceStore.shared.projectStoragePath.hasSuffix("/prototype"))
        PrototypeDesignerRuntime.reset()
    }

    @Test func storagePathIsEmptyWithoutOpenProject() {
        PrototypeDesignerRuntime.reset()
        #expect(WorkspaceStore.shared.projectStoragePath.isEmpty)
        #expect(WorkspaceStore.shared.projects.isEmpty)
        #expect(WorkspaceStore.shared.lastError == nil)
    }

    /// 空态（无原型项目）时不应有任何可渲染的选中态，主面板直接展示 onboarding 引导。
    ///
    /// 该分支曾额外渲染一个只含刷新按钮的顶部工具栏，与引导内容重复；
    /// 刷新入口已在侧边栏 Rail 提供，因此该工具栏已移除。这里锁定触发条件，
    /// 确保空态的 UI 分支入口保持单一。
    @Test func emptyStateHasNoSelectionAndNeedsNoToolbar() {
        PrototypeDesignerRuntime.reset()
        #expect(WorkspaceStore.shared.projects.isEmpty)
        #expect(WorkspaceStore.shared.selectedProject == nil)
        #expect(WorkspaceStore.shared.selectedScreen == nil)
    }

    // MARK: - Skill

    @Test func skillContributorLoadsPrototypeDesignerSkill() {
        let contributor = PrototypeDesignerSkillContributor()
        #expect(contributor.providerID == "com.coffic.lumi.plugin.prototype-designer")
        let names = contributor.allSkills.map(\.name)
        #expect(names.contains("prototype-designer"))

        // 技能正文必须真的加载到，否则模型拿不到工具指南。
        let skill = contributor.allSkills.first { $0.name == "prototype-designer" }
        let content = skill?.loadContent()
        #expect(content?.contains("prototype_preview_screen") == true)
        #expect(content?.contains("data-prototype-link") == true)
    }

    // MARK: - 端到端工具流程

    @Test func toolsCreateProjectAddScreensAndPersistInProjectStorage() async throws {
        try await withProjectStorage { root in
            let create = try await CreatePrototypeProjectTool().execute(arguments: [
                "slug": ToolArgument("checkout-flow"),
                "title": ToolArgument("Checkout Flow"),
                "style": ToolArgument("wireframe"),
                "deviceKind": ToolArgument("iPhone15Pro"),
            ])
            #expect(create.contains("checkout-flow"))
            #expect(create.contains("1179x2556"))

            let addHome = try await AddPrototypeScreenTool().execute(arguments: [
                "projectId": ToolArgument("checkout-flow"),
                "screenId": ToolArgument("01-home"),
                "title": ToolArgument("首页"),
            ])
            #expect(addHome.contains("01-home"))
            #expect(FileManager.default.fileExists(
                atPath: root.appendingPathComponent("tasks/checkout-flow/01-home/index.html").path
            ))

            _ = try await AddPrototypeScreenTool().execute(arguments: [
                "projectId": ToolArgument("checkout-flow"),
                "screenId": ToolArgument("02-detail"),
                "title": ToolArgument("详情"),
            ])

            // 读取项目结构：应能看到两屏与起始屏。
            let read = try await ReadPrototypeProjectTool().execute(arguments: [
                "projectId": ToolArgument("checkout-flow"),
            ])
            #expect(read.contains("01-home"))
            #expect(read.contains("02-detail"))
            #expect(read.contains("startScreen=01-home"))

            let list = try await ListPrototypeProjectsTool().execute(arguments: [:])
            #expect(list.contains("checkout-flow"))

            let lint = try await LintPrototypeTool().execute(arguments: [
                "projectId": ToolArgument("checkout-flow"),
            ])
            #expect(lint.contains("PASS"))
        }
    }

    @Test func patchToolAppliesExactUniqueReplacement() async throws {
        try await withProjectStorage { root in
            _ = try await CreatePrototypeProjectTool().execute(arguments: [
                "slug": ToolArgument("flow"),
                "title": ToolArgument("Flow"),
                "style": ToolArgument("wireframe"),
                "deviceKind": ToolArgument("iPhoneSE"),
            ])
            _ = try await AddPrototypeScreenTool().execute(arguments: [
                "projectId": ToolArgument("flow"),
                "screenId": ToolArgument("home"),
                "title": ToolArgument("Home"),
            ])

            let before = try await ReadPrototypeHTMLTool().execute(arguments: [
                "projectId": ToolArgument("flow"),
                "screenId": ToolArgument("home"),
            ])
            #expect(before.contains("--- HTML ---"))

            let patched = try await PatchPrototypeHTMLTool().execute(arguments: [
                "projectId": ToolArgument("flow"),
                "screenId": ToolArgument("home"),
                "operations": ToolArgument([
                    ["oldText": "<div class=\"brand\">Flow</div>", "newText": "<div class=\"brand\">结账</div>"],
                ]),
            ])
            #expect(patched.contains("Applied 1 HTML patches"))

            let after = try await ReadPrototypeHTMLTool().execute(arguments: [
                "projectId": ToolArgument("flow"),
                "screenId": ToolArgument("home"),
            ])
            #expect(after.contains("结账"))
            #expect(!after.contains("<div class=\"brand\">Flow</div>"))
        }
    }

    @Test func patchToolRejectsMissingTextWithoutWriting() async throws {
        try await withProjectStorage { root in
            _ = try await CreatePrototypeProjectTool().execute(arguments: [
                "slug": ToolArgument("flow"),
                "title": ToolArgument("Flow"),
                "style": ToolArgument("hiFi"),
                "deviceKind": ToolArgument("desktop"),
            ])
            _ = try await AddPrototypeScreenTool().execute(arguments: [
                "projectId": ToolArgument("flow"),
                "screenId": ToolArgument("home"),
                "title": ToolArgument("Home"),
            ])

            var didThrow = false
            do {
                _ = try await PatchPrototypeHTMLTool().execute(arguments: [
                    "projectId": ToolArgument("flow"),
                    "screenId": ToolArgument("home"),
                    "operations": ToolArgument([["oldText": "<absent>", "newText": "x"]]),
                ])
            } catch {
                didThrow = true
            }
            #expect(didThrow)
            _ = root
        }
    }

    @Test func replaceHTMLRejectsDanglingNavigationTarget() async throws {
        try await withProjectStorage { _ in
            _ = try await CreatePrototypeProjectTool().execute(arguments: [
                "slug": ToolArgument("flow"),
                "title": ToolArgument("Flow"),
                "style": ToolArgument("wireframe"),
                "deviceKind": ToolArgument("iPhone15Pro"),
            ])
            _ = try await AddPrototypeScreenTool().execute(arguments: [
                "projectId": ToolArgument("flow"),
                "screenId": ToolArgument("home"),
                "title": ToolArgument("Home"),
            ])

            let dangling = """
            <!doctype html><html><head><meta name="viewport" content="width=device-width"></head>
            <body style="background:#fff; overflow:hidden">
            <div data-block="x" data-block-label="X" data-prototype-link="ghost">go</div>
            </body></html>
            """
            var didThrow = false
            do {
                _ = try await ReplacePrototypeHTMLTool().execute(arguments: [
                    "projectId": ToolArgument("flow"),
                    "screenId": ToolArgument("home"),
                    "html": ToolArgument(dangling),
                ])
            } catch {
                didThrow = true
            }
            #expect(didThrow)
        }
    }

    @Test func linkingBetweenScreensIsRecordedInProjectSummary() async throws {
        try await withProjectStorage { _ in
            _ = try await CreatePrototypeProjectTool().execute(arguments: [
                "slug": ToolArgument("flow"),
                "title": ToolArgument("Flow"),
                "style": ToolArgument("wireframe"),
                "deviceKind": ToolArgument("iPhone15Pro"),
            ])
            for screenID in ["01-home", "02-detail"] {
                _ = try await AddPrototypeScreenTool().execute(arguments: [
                    "projectId": ToolArgument("flow"),
                    "screenId": ToolArgument(screenID),
                    "title": ToolArgument(screenID),
                ])
            }

            let linked = """
            <!doctype html><html><head><meta name="viewport" content="width=device-width"></head>
            <body style="background:#fff; overflow:hidden">
            <button data-block="primary-action" data-block-label="主操作"
                    data-prototype-link="02-detail" data-prototype-label="进入详情">查看详情</button>
            </body></html>
            """
            let replaced = try await ReplacePrototypeHTMLTool().execute(arguments: [
                "projectId": ToolArgument("flow"),
                "screenId": ToolArgument("01-home"),
                "html": ToolArgument(linked),
            ])
            #expect(replaced.contains("links=[02-detail(进入详情)]"))

            let read = try await ReadPrototypeProjectTool().execute(arguments: [
                "projectId": ToolArgument("flow"),
            ])
            #expect(read.contains("01-home -> 02-detail"))
        }
    }

    @Test func reorderAndStartScreenToolsUpdateProject() async throws {
        try await withProjectStorage { _ in
            _ = try await CreatePrototypeProjectTool().execute(arguments: [
                "slug": ToolArgument("flow"),
                "title": ToolArgument("Flow"),
                "style": ToolArgument("wireframe"),
                "deviceKind": ToolArgument("iPhone15Pro"),
            ])
            for screenID in ["a", "b"] {
                _ = try await AddPrototypeScreenTool().execute(arguments: [
                    "projectId": ToolArgument("flow"),
                    "screenId": ToolArgument(screenID),
                    "title": ToolArgument(screenID),
                ])
            }

            let reordered = try await ReorderPrototypeScreensTool().execute(arguments: [
                "projectId": ToolArgument("flow"),
                "screenIds": ToolArgument(["b", "a"]),
            ])
            #expect(reordered.contains("screens:"))

            let started = try await SetPrototypeStartScreenTool().execute(arguments: [
                "projectId": ToolArgument("flow"),
                "screenId": ToolArgument("b"),
            ])
            #expect(started.contains("Start screen set to b"))
            #expect(started.contains("startScreen=b"))
        }
    }

    @Test func updateProjectToolChangesTitleAndDevice() async throws {
        try await withProjectStorage { _ in
            _ = try await CreatePrototypeProjectTool().execute(arguments: [
                "slug": ToolArgument("flow"),
                "title": ToolArgument("Flow"),
                "style": ToolArgument("wireframe"),
                "deviceKind": ToolArgument("iPhoneSE"),
            ])
            let updated = try await UpdatePrototypeProjectTool().execute(arguments: [
                "projectId": ToolArgument("flow"),
                "title": ToolArgument("结账流程"),
                "deviceKind": ToolArgument("iPhone15ProMax"),
            ])
            #expect(updated.contains("结账流程"))
            #expect(updated.contains("iPhone15ProMax"))
            #expect(updated.contains("1290x2796"))
        }
    }

    @Test func importAssetToolCopiesIntoScreenReferencablePath() async throws {
        try await withProjectStorage { root in
            _ = try await CreatePrototypeProjectTool().execute(arguments: [
                "slug": ToolArgument("flow"),
                "title": ToolArgument("Flow"),
                "style": ToolArgument("hiFi"),
                "deviceKind": ToolArgument("desktop"),
            ])

            let source = root.appendingPathComponent("shot.png")
            try Self.writePNG(to: source, width: 4, height: 4)

            let imported = try await ImportPrototypeAssetTool().execute(arguments: [
                "projectId": ToolArgument("flow"),
                "sourcePath": ToolArgument(source.path),
                "fileName": ToolArgument("shot.png"),
            ])
            #expect(imported.contains("relativePath=../assets/shot.png"))
            #expect(FileManager.default.fileExists(
                atPath: root.appendingPathComponent("tasks/flow/assets/shot.png").path
            ))
        }
    }

    @Test func toolsRequireAnOpenProject() async throws {
        PrototypeDesignerRuntime.reset()
        var didThrow = false
        do {
            _ = try await CreatePrototypeProjectTool().execute(arguments: [
                "slug": ToolArgument("requires-project"),
                "title": ToolArgument("Requires Project"),
                "style": ToolArgument("wireframe"),
                "deviceKind": ToolArgument("iPhone15Pro"),
            ])
        } catch {
            didThrow = true
        }
        #expect(didThrow)
    }

    // MARK: - 生命周期

    @Test func activatingPluginEntryShowsChatAndActivatesRail() async throws {
        PrototypeDesignerRuntime.reset()
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

        try kernel.start(plugins: [PrototypeDesignerPlugin()])
        try await kernel.enablePlugin(id: PrototypeDesignerPlugin().id)

        #expect(activity.activeItemID == "com.coffic.lumi.plugin.prototype-designer.entry")
        #expect(rail.activeTabID == PrototypeDesignerPlugin.railTabID)
        #expect(chat.isVisible)
        #expect(chat.isContextActive)
        #expect(rootView.isContentHeaderViewHidden)
        #expect(!rootView.isRailViewVisible)
        #expect(toolbar.visibleCategories == [.global, .project, .chat, .design])

        try kernel.stop()

        #expect(rootView.isContentHeaderViewHidden == false)
        #expect(rootView.isRailViewVisible == rail.hasVisibleTabs)
    }

    // MARK: - 测试辅助

    /// 在唯一临时目录内建立项目存储并执行测试体。
    private func withProjectStorage(_ body: (URL) async throws -> Void) async throws {
        PrototypeDesignerRuntime.reset()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("prototype-plugin-\(UUID().uuidString)", isDirectory: true)
        let projectRoot = root.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        PrototypeDesignerRuntime.setProjectStorage(
            projectPath: projectRoot.path,
            projectStorageDirectory: projectRoot
        )
        try await body(projectRoot)
    }

    /// 写出一张最小可解码的 PNG。
    private static func writePNG(to url: URL, width: Int, height: Int) throws {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        guard let context, let image = context.makeImage(),
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw PrototypeAssetError.unsupportedImage(url.path)
        }
        try data.write(to: url, options: .atomic)
    }
}
