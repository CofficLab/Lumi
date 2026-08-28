import EditorService
import Foundation
import PluginCodeEditor
import Testing

@MainActor
struct CodeEditorViewModelTests {
    @Test("loads the current project file into the editor")
    func loadsCurrentFile() async throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodeEditorViewModel-\(UUID().uuidString).swift")
        try "let value = 1\n".write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }

        let editor = EditorService(editorExtensionRegistry: EditorExtensionRegistry())
        let viewModel = CodeEditorViewModel(editor: editor)

        viewModel.updateCurrentFile(file)
        await waitForFileLoad(editor)

        #expect(viewModel.currentFileURL == file.standardizedFileURL)
        #expect(editor.files.currentFileURL == file.standardizedFileURL)
        #expect(editor.files.content?.string == "let value = 1\n")
    }

    @Test("clearing the current project file clears the editor")
    func clearsCurrentFile() async throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodeEditorViewModel-Clear-\(UUID().uuidString).swift")
        try "let value = 1\n".write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }

        let editor = EditorService(editorExtensionRegistry: EditorExtensionRegistry())
        let viewModel = CodeEditorViewModel(editor: editor)

        viewModel.updateCurrentFile(file)
        await waitForFileLoad(editor)
        viewModel.updateCurrentFile(nil)

        #expect(viewModel.currentFileURL == nil)
        #expect(editor.files.currentFileURL == nil)
        #expect(editor.files.content == nil)
    }

    private func waitForFileLoad(_ editor: EditorService) async {
        for _ in 0..<100 where editor.state.isFileLoadInProgress {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}
