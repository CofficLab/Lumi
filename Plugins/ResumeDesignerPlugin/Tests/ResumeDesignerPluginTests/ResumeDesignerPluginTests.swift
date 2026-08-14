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

        #expect(WorkspaceStore.shared.projectResumes.isEmpty)
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

        // 没有打开项目时,默认走 app scope。
        let create = try await CreateResumeTool().execute(
            arguments: [
                "slug": .string("my-resume"),
                "title": .string("Ada Lovelace"),
                "paper": .string("a4"),
                "template": .string("classic"),
            ],
            kernel: kernel
        )
        #expect(create.contains("scope=app"))
        #expect(create.contains("Created resume"))
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

    @Test func explicitScopeRoutesWriteOperations() async throws {
        Runtime.reset()
        let appRoot = FileManager.default.temporaryDirectory.appendingPathComponent("app-\(UUID().uuidString)", isDirectory: true)
        let projectRoot = FileManager.default.temporaryDirectory.appendingPathComponent("project-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: appRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: appRoot)
            try? FileManager.default.removeItem(at: projectRoot)
        }
        let kernel = KernelLumi()
        Runtime.configure(appStorageDirectory: appRoot)
        Runtime.setProjectStorage(projectPath: projectRoot.path, projectStorageDirectory: projectRoot)

        let createArguments: [String: LumiJSONValue] = [
            "slug": .string("scoped"),
            "title": .string("Scoped"),
            "paper": .string("a4"),
            "template": .string("minimal"),
        ]
        _ = try await CreateResumeTool().execute(
            arguments: createArguments.merging(["scope": .string("app")]) { _, new in new },
            kernel: kernel
        )
        _ = try await CreateResumeTool().execute(
            arguments: createArguments.merging(["scope": .string("project")]) { _, new in new },
            kernel: kernel
        )

        // 文件系统隔离:每个 scope 各自存储。
        #expect(FileManager.default.fileExists(atPath: appRoot.appendingPathComponent("resumes/scoped/manifest.json").path))
        #expect(FileManager.default.fileExists(atPath: projectRoot.appendingPathComponent("resumes/scoped/manifest.json").path))
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
