import Foundation
import Testing

@testable import StoryWriterPlugin

@Suite("Story 导出后台写盘（issue #1248）")
struct StoryExportOffMainTests {
    @Test("导出写入可在后台任务完成，内容完整一致")
    func writesOffMain() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StoryExportTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let markdown = String(repeating: "# Chapter\n\n正文 content.\n", count: 5000)
        let destination = directory.appendingPathComponent("story.md")

        try await Task.detached(priority: .userInitiated) {
            try StoryEditorView.writeMarkdownFile(markdown, to: destination)
        }.value

        let written = try String(contentsOf: destination, encoding: .utf8)
        #expect(written == markdown)
    }

    @Test("写入失败抛出错误，供 UI 提示而不是静默吞掉")
    func writeFailureThrows() async throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("StoryExportMissing-\(UUID().uuidString)/story.md")

        await #expect(throws: (any Error).self) {
            try await Task.detached(priority: .userInitiated) {
                try StoryEditorView.writeMarkdownFile("x", to: missing)
            }.value
        }
    }
}