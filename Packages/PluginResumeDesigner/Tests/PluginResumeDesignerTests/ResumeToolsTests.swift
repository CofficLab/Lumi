import AgentToolKit
import Foundation
import ResumeKit
import Testing
@testable import PluginResumeDesigner

/// Agent 工具层测试：覆盖 create / list / read / lint / patch 以及参数校验。
///
/// 属于 `ResumeDesignerSuite`（见 ResumeDesignerPluginTests.swift）的 extension，
/// 以共享全局单例 `WorkspaceStore.shared` 并受 `.serialized` 串行约束。
extension ResumeDesignerSuite {

    @Test("resume_create 创建简历并落盘（manifest + index.html）")
    func createResumeToolCreatesDocument() async throws {
        let directory = makeTemporaryStorage()
        defer { cleanup(directory) }

        let result = try await CreateResumeTool().execute(arguments: arguments([
            "slug": "zhang-san",
            "title": "张三",
            "paper": "a4",
            "template": "classic",
        ]))

        #expect(result.contains("zhang-san"))
        #expect(result.contains("张三"))
        #expect(result.contains("794x1123 px"))
        #expect(WorkspaceStore.shared.appResumes.contains { $0.id == "zhang-san" })
        #expect(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("resumes/zhang-san/manifest.json").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("resumes/zhang-san/index.html").path
        ))
    }

    @Test("resume_list 列出已创建的简历")
    func listResumesToolListsDocuments() async throws {
        let directory = makeTemporaryStorage()
        defer { cleanup(directory) }

        _ = try await CreateResumeTool().execute(arguments: arguments([
            "slug": "li-si",
            "title": "李四",
            "paper": "letter",
            "template": "modern",
        ]))

        let result = try await ListResumesTool().execute(arguments: [:])
        #expect(result.contains("Found 1 resume(s)"))
        #expect(result.contains("li-si"))
        #expect(result.contains("李四"))
    }

    @Test("resume_read 返回 manifest 元数据")
    func readResumeToolReturnsMetadata() async throws {
        let directory = makeTemporaryStorage()
        defer { cleanup(directory) }

        _ = try await CreateResumeTool().execute(arguments: arguments([
            "slug": "wang-wu",
            "title": "王五",
            "paper": "a4",
            "template": "minimal",
        ]))

        let result = try await ReadResumeTool().execute(arguments: arguments(["resumeId": "wang-wu"]))
        #expect(result.contains("wang-wu"))
        #expect(result.contains("paper=a4"))
        #expect(result.contains("template=minimal"))
    }

    @Test("resume_lint 对模板输出 PASS")
    func lintResumeToolPassesOnTemplate() async throws {
        let directory = makeTemporaryStorage()
        defer { cleanup(directory) }

        _ = try await CreateResumeTool().execute(arguments: arguments([
            "slug": "zhao-liu",
            "title": "赵六",
            "paper": "a4",
            "template": "classic",
        ]))

        let result = try await LintResumeTool().execute(arguments: arguments(["resumeId": "zhao-liu"]))
        #expect(result.contains("Static lint: PASS"))
        #expect(result.contains("Overall: PASS"))
    }

    @Test("resume_patch_html 原子应用补丁并更新 HTML")
    func patchResumeHTMLToolAppliesPatch() async throws {
        let directory = makeTemporaryStorage()
        defer { cleanup(directory) }

        _ = try await CreateResumeTool().execute(arguments: arguments([
            "slug": "sun-qi",
            "title": "孙七",
            "paper": "a4",
            "template": "classic",
        ]))

        let result = try await PatchResumeHTMLTool().execute(arguments: arguments([
            "resumeId": "sun-qi",
            "operations": [
                [
                    "oldText": "Skill one · Skill two · Skill three · Skill four",
                    "newText": "Swift · SwiftUI · UIKit · Core Data",
                ],
            ],
        ]))

        #expect(result.contains("Applied 1 HTML patches"))
        let resume = try ResumeToolSupport.store.readResume(
            storagePath: WorkspaceStore.shared.appStoragePath,
            slug: "sun-qi"
        )
        #expect(resume.html.contains("Swift · SwiftUI"))
        #expect(!resume.html.contains("Skill one"))
    }

    @Test("resume_create 拒绝非法 paper 值")
    func createResumeToolRejectsInvalidPaper() async {
        let directory = makeTemporaryStorage()
        defer { cleanup(directory) }

        await #expect(throws: ResumeToolSupport.ResumeToolArgumentError.self) {
            _ = try await CreateResumeTool().execute(arguments: arguments([
                "slug": "test-user",
                "title": "Test",
                "paper": "a3",
                "template": "classic",
            ]))
        }
        #expect(WorkspaceStore.shared.appResumes.isEmpty)
    }

    @Test("resume_create 缺少必填 slug 抛错")
    func createResumeToolRejectsMissingSlug() async {
        let directory = makeTemporaryStorage()
        defer { cleanup(directory) }

        await #expect(throws: ResumeToolSupport.ResumeToolArgumentError.self) {
            _ = try await CreateResumeTool().execute(arguments: arguments([
                "title": "Test",
                "paper": "a4",
                "template": "classic",
            ]))
        }
    }
}
