import EditorService
import Foundation
import PluginEditorWorkspace
import ProviderProject
import Testing

@MainActor
struct EditorWorkspaceControllerTests {
    @Test("restores project tabs and active file")
    func restoresProjectState() async throws {
        let fixture = try ProjectFixture()
        let first = try fixture.write("A.swift", "let a = 1")
        let second = try fixture.write("B.swift", "let b = 2")
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("outside.swift")
        let project = TestProjectProvider(
            root: fixture.root,
            openFiles: [first, second, first, outside],
            currentFile: second
        )
        let editor = EditorService(editorExtensionRegistry: EditorExtensionRegistry())

        let controller = EditorWorkspaceController(editor: editor, project: project)
        await waitForFileLoad(editor)

        #expect(controller.rootURL == fixture.root.standardizedFileURL)
        #expect(editor.sessions.tabs.compactMap(\.fileURL) == [first, second])
        #expect(editor.sessions.activeSession?.fileURL == second)
        #expect(controller.selectedFileURL == second)
    }

    @Test("opening a file updates project persistence")
    func openingFilePersistsState() async throws {
        let fixture = try ProjectFixture()
        let file = try fixture.write("Sources/App.swift", "print(1)")
        let project = TestProjectProvider(root: fixture.root)
        let editor = EditorService(editorExtensionRegistry: EditorExtensionRegistry())
        let controller = EditorWorkspaceController(editor: editor, project: project)

        controller.openFile(file)
        await waitForPropagation()

        #expect(editor.sessions.activeSession?.fileURL == file)
        #expect(project.openFileURLs == [file])
        #expect(project.currentFileURL == file)
    }

    @Test("rejects files outside the current project")
    func rejectsOutsideFile() throws {
        let fixture = try ProjectFixture()
        let project = TestProjectProvider(root: fixture.root)
        let editor = EditorService(editorExtensionRegistry: EditorExtensionRegistry())
        let controller = EditorWorkspaceController(editor: editor, project: project)
        let outside = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditorWorkspaceOutside-\(UUID().uuidString).swift")
        try "let value = 1".write(to: outside, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: outside) }

        controller.openFile(outside)

        #expect(editor.sessions.tabs.isEmpty)
        #expect(project.openFileURLs.isEmpty)
    }

    private func waitForFileLoad(_ editor: EditorService) async {
        for _ in 0..<100 where editor.state.isFileLoadInProgress {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    private func waitForPropagation() async {
        try? await Task.sleep(for: .milliseconds(30))
    }
}

@MainActor
private final class TestProjectProvider: ProjectProviding {
    @Published var currentProject: ProjectInfo?
    @Published var openFileURLs: [URL]
    @Published var currentFileURL: URL?
    @Published var projects: [ProjectInfo]

    init(root: URL, openFiles: [URL] = [], currentFile: URL? = nil) {
        let info = ProjectInfo(name: root.lastPathComponent, path: root.path)
        currentProject = info
        openFileURLs = openFiles
        currentFileURL = currentFile
        projects = [info]
    }

    func openProject(at path: String) async throws {
        currentProject = ProjectInfo(name: URL(fileURLWithPath: path).lastPathComponent, path: path)
    }

    func updateCurrentFile(_ fileURL: URL?) { currentFileURL = fileURL }
    func updateOpenFiles(_ fileURLs: [URL]) { openFileURLs = fileURLs }
    func closeFile(_ fileURL: URL) { openFileURLs.removeAll { $0 == fileURL } }
    func closeProject() async { currentProject = nil }
    func refreshProjects() async throws {}
    func synchronizeProjects(_ projects: [ProjectInfo]) { self.projects = projects }
}

private struct ProjectFixture {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditorWorkspaceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func write(_ relativePath: String, _ contents: String) throws -> URL {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url.standardizedFileURL
    }
}
