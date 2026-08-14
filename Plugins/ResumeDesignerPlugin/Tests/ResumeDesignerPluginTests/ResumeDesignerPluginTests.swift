import Foundation
import KernelLumi
import ResumeKit
import Testing
@testable import ResumeDesignerPlugin

@MainActor
@Suite("Resume designer plugin", .serialized)
struct ResumeDesignerPluginTests {
    @Test func openingWithoutConfiguredStorageDoesNotShowAnError() {
        Runtime.reset()
        WorkspaceStore.shared.reload()

        #expect(WorkspaceStore.shared.appResumes.isEmpty)
        #expect(WorkspaceStore.shared.lastError == nil)
    }

    @Test func contributesOptInWorkspaceAndCompleteToolSet() {
        let plugin = ResumeDesignerPlugin()
        let kernel = KernelLumi()
        #expect(plugin.id == "com.coffic.lumi.plugin.resume-designer")
        #expect(plugin.policy == .optIn)
        #expect(plugin.viewContainers(kernel: kernel).count == 1)
        #expect(plugin.panelRailTabItems(kernel: kernel).count == 1)
        let names = Set(plugin.agentTools(kernel: kernel).map(\.name))
        #expect(names == [
            "resume_list",
            "resume_create",
            "resume_read",
            "resume_read_html",
            "resume_replace_html",
            "resume_patch_html",
            "resume_import_asset",
            "resume_lint",
            "resume_preview_page",
            "resume_export",
        ])
    }

    /// 运行时启用插件（onEnable）必须配置 app 存储目录，否则 rail 会误报
    /// "插件存储不可用"。onBoot 只在启动时对已启用插件执行一次。
    @Test func onEnableConfiguresAppStorageDirectory() async throws {
        Runtime.reset()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let kernel = KernelLumi()
        try kernel.registerStorage(MockStorage(dataRootDirectory: root))

        let plugin = ResumeDesignerPlugin()
        try await plugin.onEnable(kernel: kernel)

        #expect(WorkspaceStore.shared.appStorageDirectory != nil)
        #expect(WorkspaceStore.shared.appStorageDirectory?.lastPathComponent == "ResumeDesigner")
        #expect(WorkspaceStore.shared.appResumes.isEmpty)
        #expect(WorkspaceStore.shared.lastError == nil)
    }

    @Test func overwriteExportIsHighRisk() {
        let tool = ExportResumeTool()
        let kernel = KernelLumi()
        #expect(tool.riskLevel(arguments: ["overwrite": .bool(false)], kernel: kernel) == .medium)
        #expect(tool.riskLevel(arguments: ["overwrite": .bool(true)], kernel: kernel) == .high)
    }

    @Test func agentToolsCreatePatchAndLintResumeInAppStorage() async throws {
        Runtime.reset()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let kernel = KernelLumi()
        Runtime.configure(appStorageDirectory: root)

        // 简历始终写入应用数据目录（app 存储）。
        let create = try await CreateResumeTool().execute(
            arguments: [
                "slug": .string("my-resume"),
                "title": .string("Ada Lovelace"),
                "paper": .string("a4"),
                "template": .string("classic"),
            ],
            kernel: kernel
        )
        #expect(create.contains("Created resume"))
        #expect(!create.contains("scope="))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("resumes/my-resume/index.html").path))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("resumes/my-resume/manifest.json").path))

        let read = try await ReadResumeTool().execute(
            arguments: ["resumeId": .string("my-resume")],
            kernel: kernel
        )
        #expect(read.contains("paper=a4"))
        #expect(read.contains("template=classic"))

        let readHTML = try await ReadResumeHTMLTool().execute(
            arguments: ["resumeId": .string("my-resume")],
            kernel: kernel
        )
        #expect(readHTML.contains("resume-page"))

        let patched = try await PatchResumeHTMLTool().execute(
            arguments: [
                "resumeId": .string("my-resume"),
                "operations": .array([
                    .object([
                        "oldText": .string("<h1>Ada Lovelace</h1>"),
                        "newText": .string("<h1>Ada Lovelace, Engineer</h1>"),
                    ]),
                ]),
            ],
            kernel: kernel
        )
        #expect(patched.contains("Applied 1 HTML patches"))

        // 列表能找到新建简历。
        let list = try await ListResumesTool().execute(arguments: [:], kernel: kernel)
        #expect(list.contains("my-resume"))
    }

    @Test func blankTemplateSupportsFullyCustomDesign() async throws {
        Runtime.reset()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let kernel = KernelLumi()
        Runtime.configure(appStorageDirectory: root)

        _ = try await CreateResumeTool().execute(
            arguments: [
                "slug": .string("custom"),
                "title": .string("Custom"),
                "paper": .string("letter"),
                "template": .string("blank"),
            ],
            kernel: kernel
        )
        let html = try await ReadResumeHTMLTool().execute(
            arguments: ["resumeId": .string("custom")],
            kernel: kernel
        )
        #expect(html.contains("816px"))
        #expect(html.contains("1056px"))
    }

    @Test func toolsIgnoreLegacyScopeArgumentAndAlwaysUseAppStorage() async throws {
        Runtime.reset()
        let appRoot = FileManager.default.temporaryDirectory.appendingPathComponent("app-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: appRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: appRoot) }
        let kernel = KernelLumi()
        Runtime.configure(appStorageDirectory: appRoot)

        // 即使显式传入 scope 参数（含 project），也只会写入 app 存储目录。
        let createArguments: [String: LumiJSONValue] = [
            "slug": .string("scoped"),
            "title": .string("Scoped"),
            "paper": .string("a4"),
            "template": .string("minimal"),
        ]
        let output = try await CreateResumeTool().execute(
            arguments: createArguments.merging(["scope": .string("project")]) { _, new in new },
            kernel: kernel
        )
        #expect(output.contains("Created resume"))
        #expect(!output.contains("scope="))
        #expect(FileManager.default.fileExists(atPath: appRoot.appendingPathComponent("resumes/scoped/manifest.json").path))
    }

    @Test func replaceHTMLRejectsInvalidDocuments() async throws {
        Runtime.reset()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let kernel = KernelLumi()
        Runtime.configure(appStorageDirectory: root)

        _ = try await CreateResumeTool().execute(
            arguments: [
                "slug": .string("lint-me"),
                "title": .string("Lint Me"),
                "paper": .string("a4"),
                "template": .string("classic"),
            ],
            kernel: kernel
        )
        // 带脚本的 HTML 必须被拒绝。
        await #expect(throws: ResumeStoreError.self) {
            try await ReplaceResumeHTMLTool().execute(
                arguments: [
                    "resumeId": .string("lint-me"),
                    "html": .string("<!doctype html><html><head><script>alert(1)</script></head><body><section class=\"resume-page\"></section></body></html>"),
                ],
                kernel: kernel
            )
        }
    }
}

/// 测试用 StorageProviding：以临时目录为根，按插件 ID 划分子目录。
private final class MockStorage: StorageProviding {
    let dataRootDirectory: URL
    init(dataRootDirectory: URL) { self.dataRootDirectory = dataRootDirectory }
    func pluginDataDirectory(for pluginID: String) -> URL {
        dataRootDirectory.appendingPathComponent(pluginID, isDirectory: true)
    }
    func coreDataDirectory() -> URL {
        dataRootDirectory.appendingPathComponent("Core", isDirectory: true)
    }
}
