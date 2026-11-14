import AppKit
import Foundation
import ProviderProject
import Testing
@testable import PluginEditorPreview

/// 编辑器预览的文件元数据轮询（见 issue #1245）。
///
/// 预览每秒比对一次文件的修改时间与大小，元数据探测是同步文件系统 IO，
/// 原先在主线程执行；修复后改到后台线程，只把小的值类型签名带回主线程。
@MainActor
struct EditorPreviewPollingTests {

    private func makeTemporaryMarkdown(contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-preview-poll-\(UUID().uuidString).md")
        try Data(contents.utf8).write(to: url)
        return url
    }

    @Test("内容变化后预览重读到新内容")
    func reloadsAfterFileChange() async throws {
        let url = try makeTemporaryMarkdown(contents: "# First")
        defer { try? FileManager.default.removeItem(at: url) }

        let project = DefaultProjectProvider()
        let viewModel = EditorPreviewViewModel(
            projectCapability: EditorPreviewProjectCapabilityAdapter(project: project),
            pollInterval: .milliseconds(50)
        )
        viewModel.updateCurrentFile(url)

        // 等首次加载完成。
        try await Task.sleep(for: .milliseconds(300))
        #expect(viewModel.state == .markdown(url, "# First"))

        // 外部写入新内容（修改时间 + 大小都变了）。
        try await Task.sleep(for: .milliseconds(20))
        try Data("# Second and longer".utf8).write(to: url)

        try await Task.sleep(for: .milliseconds(600))

        guard case .markdown(_, let content) = viewModel.state else {
            Issue.record("Expected markdown state, got \(viewModel.state)")
            return
        }
        #expect(content == "# Second and longer")
    }

    @Test("内容未变化时状态保持不变")
    func stateStableWhenFileUnchanged() async throws {
        let url = try makeTemporaryMarkdown(contents: "# Stable")
        defer { try? FileManager.default.removeItem(at: url) }

        let project = DefaultProjectProvider()
        let viewModel = EditorPreviewViewModel(
            projectCapability: EditorPreviewProjectCapabilityAdapter(project: project),
            pollInterval: .milliseconds(50)
        )
        viewModel.updateCurrentFile(url)

        try await Task.sleep(for: .milliseconds(500))

        #expect(viewModel.state == .markdown(url, "# Stable"))
    }

    @Test("文件被删除后预览不崩溃")
    func deletedFileDoesNotCrash() async throws {
        let url = try makeTemporaryMarkdown(contents: "# Gone")
        defer { try? FileManager.default.removeItem(at: url) }

        let project = DefaultProjectProvider()
        let viewModel = EditorPreviewViewModel(
            projectCapability: EditorPreviewProjectCapabilityAdapter(project: project),
            pollInterval: .milliseconds(50)
        )
        viewModel.updateCurrentFile(url)
        try await Task.sleep(for: .milliseconds(200))

        try FileManager.default.removeItem(at: url)
        try await Task.sleep(for: .milliseconds(300))

        // 状态可能保持旧内容或变为失败态，但不应崩溃。
        #expect(viewModel.state != .empty)
    }
}
