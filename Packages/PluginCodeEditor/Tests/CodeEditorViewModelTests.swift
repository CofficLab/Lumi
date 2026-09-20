import Foundation
import KernelCore
import PluginCodeEditor
import ProviderEditor
import PluginCodeEditorHost
import Testing

@MainActor
struct CodeEditorViewModelTests {
    @Test("loads the current project file into the editor")
    func loadsCurrentFile() async throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodeEditorViewModel-\(UUID().uuidString).swift")
        try "let value = 1\n".write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }

        let kernel = KernelCoreContainer()
        try kernel.start(plugins: [CodeEditorHostSuperPlugin()])
        defer { try? kernel.stop() }
        let provider = try #require(kernel.resolveProvider(EditorProviding.self))
        let viewModel = CodeEditorViewModel(editor: provider)

        viewModel.updateCurrentFile(file)
        await waitForDocument(provider, fileURL: file)

        #expect(viewModel.currentFileURL == file.standardizedFileURL)
        #expect(provider.documents.activeDocument?.uri == file.standardizedFileURL)
        let document = try #require(provider.documents.activeDocument)
        let snapshot = try await provider.documents.snapshot(documentID: document.id)
        #expect(snapshot.text == "let value = 1\n")
    }

    @Test("clearing the current project file clears the editor")
    func clearsCurrentFile() async throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodeEditorViewModel-Clear-\(UUID().uuidString).swift")
        try "let value = 1\n".write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }

        let kernel = KernelCoreContainer()
        try kernel.start(plugins: [CodeEditorHostSuperPlugin()])
        defer { try? kernel.stop() }
        let provider = try #require(kernel.resolveProvider(EditorProviding.self))
        let viewModel = CodeEditorViewModel(editor: provider)

        viewModel.updateCurrentFile(file)
        await waitForDocument(provider, fileURL: file)
        viewModel.updateCurrentFile(nil)
        for _ in 0..<100 where provider.documents.activeDocument != nil {
            try? await Task.sleep(for: .milliseconds(10))
        }

        #expect(viewModel.currentFileURL == nil)
        #expect(provider.documents.activeDocument == nil)
    }

    private func waitForDocument(_ editor: any EditorProviding, fileURL: URL) async {
        for _ in 0..<100 where editor.documents.activeDocument?.uri != fileURL.standardizedFileURL {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}
