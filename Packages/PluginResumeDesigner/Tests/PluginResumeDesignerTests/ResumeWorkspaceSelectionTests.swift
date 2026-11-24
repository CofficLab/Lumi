import KitResume
import Foundation
import Testing
@testable import PluginResumeDesigner

/// 选中简历行的开销（见 issue #1177）。
///
/// 原先每次 `select` 都会重读选中简历的 manifest 并整读 `index.html`，
/// 即使同一行已被加载；点击延迟随 HTML 大小与存储延迟增长。
///
/// 这些用例会改动全局 `WorkspaceStore.shared`，因此以扩展形式并入
/// 插件主测试套件（已标记 `.serialized`），与其他改动同一全局状态的
/// 用例串行执行，避免并行时互相污染。
extension ResumeDesignerSuite {

    private func makeSelectionProjectRoot(_ name: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("resume-select-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func activateStorage(for project: URL) {
        ResumeDesignerRuntime.reset()
        let storage = project
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent(ResumeDesignerRuntime.projectFolderName, isDirectory: true)
        ResumeDesignerRuntime.setProjectStorage(projectPath: project.path, projectStorageDirectory: storage)
    }

    @Test("重复选中同一份简历不重新读取文档")
    func repeatedSelectionOfSameResumeDoesNotRereadDocument() throws {
        let project = try makeSelectionProjectRoot("repeat")
        defer { try? FileManager.default.removeItem(at: project) }
        activateStorage(for: project)
        let workspace = WorkspaceStore.shared
        _ = try workspace.documentStore.createResume(
            storagePath: workspace.projectStoragePath,
            slug: "ada",
            title: "Ada Lovelace",
            paper: .a4,
            template: .classic
        )
        workspace.reload()
        workspace.select(resumeID: "ada")
        let loaded = try #require(workspace.selectedResume)
        let originalHTML = loaded.html

        // 磁盘上的 HTML 被外部改写：重复选中同一行不应再读盘。
        try "corrupted".write(to: loaded.htmlURL, atomically: true, encoding: .utf8)
        workspace.select(resumeID: "ada")

        #expect(workspace.selectedResume?.html == originalHTML)
    }

    @Test("选中另一份简历仍会加载其文档")
    func selectingAnotherResumeStillLoadsItsDocument() throws {
        let project = try makeSelectionProjectRoot("switch")
        defer { try? FileManager.default.removeItem(at: project) }
        activateStorage(for: project)
        let workspace = WorkspaceStore.shared
        _ = try workspace.documentStore.createResume(
            storagePath: workspace.projectStoragePath,
            slug: "ada",
            title: "Ada Lovelace",
            paper: .a4,
            template: .classic
        )
        _ = try workspace.documentStore.createResume(
            storagePath: workspace.projectStoragePath,
            slug: "grace",
            title: "Grace Hopper",
            paper: .a4,
            template: .classic
        )
        workspace.reload()
        workspace.select(resumeID: "ada")
        #expect(workspace.selectedResume?.document.id == "ada")

        workspace.select(resumeID: "grace")
        #expect(workspace.selectedResume?.document.id == "grace")
    }

    @Test("加载失败后再次选中会重试读取")
    func failedSelectionRetriesOnNextSelect() throws {
        let project = try makeSelectionProjectRoot("retry")
        defer { try? FileManager.default.removeItem(at: project) }
        activateStorage(for: project)
        let workspace = WorkspaceStore.shared
        _ = try workspace.documentStore.createResume(
            storagePath: workspace.projectStoragePath,
            slug: "ada",
            title: "Ada Lovelace",
            paper: .a4,
            template: .classic
        )
        workspace.reload()

        // 删除 HTML 但保留 manifest：选中加载失败，选中状态为空。
        let htmlURL = try workspace.documentStore.resumeDirectoryURL(
            storagePath: workspace.projectStoragePath,
            slug: "ada"
        ).appendingPathComponent(ResumeDocumentStore.htmlFileName)
        try FileManager.default.removeItem(at: htmlURL)
        workspace.select(resumeID: "ada")
        #expect(workspace.selectedResume == nil)

        // 补回 HTML 后再次选中：早退分支不适用（尚未加载），应重试并成功。
        try "restored".write(to: htmlURL, atomically: true, encoding: .utf8)
        workspace.select(resumeID: "ada")
        #expect(workspace.selectedResume?.html == "restored")
    }
}
