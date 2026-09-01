import Foundation
import ProviderProject
import Testing
@testable import PluginEditorPreview

@MainActor
struct EditorPreviewTests {
    @Test("recognizes Markdown extensions")
    func markdownExtensions() {
        #expect(EditorPreviewViewModel.kind(for: URL(fileURLWithPath: "/tmp/README.md")) == .markdown)
        #expect(EditorPreviewViewModel.kind(for: URL(fileURLWithPath: "/tmp/notes.MARKDOWN")) == .markdown)
    }

    @Test("recognizes common image extensions")
    func imageExtensions() {
        #expect(EditorPreviewViewModel.kind(for: URL(fileURLWithPath: "/tmp/image.png")) == .image)
        #expect(EditorPreviewViewModel.kind(for: URL(fileURLWithPath: "/tmp/image.HEIC")) == .image)
    }

    @Test("falls back for unsupported files")
    func unsupportedExtensions() {
        #expect(EditorPreviewViewModel.kind(for: URL(fileURLWithPath: "/tmp/main.swift")) == .unsupported)
    }

    @Test("unsupported preview states do not keep the Content Footer")
    func unsupportedStatesHidePreviewFooter() {
        #expect(!EditorPreviewState.empty.showsPreviewFooter)
        #expect(EditorPreviewState.loading(URL(fileURLWithPath: "/tmp/README.md")).showsPreviewFooter)
        #expect(EditorPreviewState.markdown(URL(fileURLWithPath: "/tmp/README.md"), "# Preview").showsPreviewFooter)
        #expect(EditorPreviewState.image(URL(fileURLWithPath: "/tmp/image.png")).showsPreviewFooter)
        #expect(!EditorPreviewState.unsupported(URL(fileURLWithPath: "/tmp/main.swift")).showsPreviewFooter)
        #expect(EditorPreviewState.failed(URL(fileURLWithPath: "/tmp/README.md"), "read failed").showsPreviewFooter)
    }

    @Test("observes the current file from ProjectProviding")
    func projectObserverUpdatesViewModel() async throws {
        let project = DefaultProjectProvider()
        let viewModel = EditorPreviewViewModel(project: project)
        let observer = EditorPreviewProjectObserver(project: project, viewModel: viewModel)

        let filename = "lumi-editor-preview-" + UUID().uuidString + ".md"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try Data("# Preview\n".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        project.updateCurrentFile(fileURL)
        try await Task.sleep(for: .milliseconds(20))

        #expect(viewModel.state == .markdown(fileURL.standardizedFileURL, "# Preview\n"))

        observer.cancel()
        project.updateCurrentFile(nil)
        #expect(viewModel.state == .markdown(fileURL.standardizedFileURL, "# Preview\n"))
    }
}
