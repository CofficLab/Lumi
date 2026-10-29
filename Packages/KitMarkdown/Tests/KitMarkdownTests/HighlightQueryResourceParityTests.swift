import Foundation
import Testing
@testable import KitMarkdown

/// tree-sitter 高亮查询文件的防漂移守卫。
///
/// 查询文件同时存在于两处：
/// - `KitMarkdown/Resources/tree-sitter-*/highlights.scm`（聊天等 Markdown 渲染）
/// - `PluginCodeEditorLanguages/Resources/tree-sitter-*/highlights.scm`（代码编辑器）
///
/// 两份必须逐字节一致，否则编辑器与聊天的语法着色会出现差异。
@MainActor
struct HighlightQueryResourceParityTests {

    @Test("聊天与编辑器使用同一份高亮查询文件")
    func highlightQueriesStayInSync() throws {
        let packageRoot = Self.packageRoot
        let editorResources = packageRoot
            .deletingLastPathComponent()
            .appendingPathComponent("PluginCodeEditorLanguages/Resources")

        guard FileManager.default.fileExists(atPath: editorResources.path) else {
            // 独立检出 KitMarkdown 时没有编辑器包，跳过。
            return
        }

        let markdownResources = packageRoot.appendingPathComponent("Resources")
        let folders = try FileManager.default.contentsOfDirectory(
            atPath: markdownResources.path
        ).filter { $0.hasPrefix("tree-sitter-") }

        #expect(!folders.isEmpty, "KitMarkdown 应至少包含一份高亮查询")

        for folder in folders {
            let markdownFile = markdownResources
                .appendingPathComponent(folder)
                .appendingPathComponent("highlights.scm")
            let editorFile = editorResources
                .appendingPathComponent(folder)
                .appendingPathComponent("highlights.scm")

            guard FileManager.default.fileExists(atPath: editorFile.path) else {
                Issue.record("编辑器缺少高亮查询：\(editorFile.path)")
                continue
            }

            #expect(
                try Data(contentsOf: markdownFile) == Data(contentsOf: editorFile),
                "\(folder)/highlights.scm 与编辑器版本不一致，请同步两份查询文件"
            )
        }
    }

    /// 通过编译期文件路径推导包根目录，避免依赖运行时工作目录。
    private static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)   // .../KitMarkdown/Tests/KitMarkdownTests/<file>.swift
            .deletingLastPathComponent()  // KitMarkdownTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // KitMarkdown
    }
}
