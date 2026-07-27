import Combine
import EditorService
import Foundation
import LumiKernel
import Testing
@testable import EditorProviderPlugin

@MainActor
@Suite("Editor Provider Plugin")
struct EditorProviderPluginTests {
    @Test
    func currentProjectFileOpensInEditor() async throws {
        let kernel = LumiKernel()
        let project = MockProjectService()
        kernel.registerProject(project)

        let editorService = EditorService(editorExtensionRegistry: EditorExtensionRegistry())
        kernel.registerService(EditorService.self, editorService)

        let plugin = EditorProviderPlugin()
        try await plugin.onBoot(kernel: kernel)
        try await plugin.onReady(kernel: kernel)

        let fileURL = try makeTemporarySwiftFile()
        project.updateCurrentFile(fileURL)

        await waitForEditorFile(editorService, expected: fileURL.standardizedFileURL)
    }

    private func makeTemporarySwiftFile() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Lumi")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let fileURL = directoryURL.appendingPathComponent("Main.swift")
        try "struct Main {}\n".write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    private func waitForEditorFile(
        _ editorService: EditorService,
        expected: URL
    ) async {
        for _ in 0 ..< 100 {
            if editorService.files.currentFileURL == expected {
                return
            }
            await Task.yield()
        }

        Issue.record("Expected editor current file to update to \(expected.path)")
    }
}

@MainActor
private final class MockProjectService: ProjectProviding {
    @Published var currentProject: ProjectInfo?
    @Published var openFileURLs: [URL] = []
    @Published var currentFileURL: URL?
    @Published var projects: [ProjectInfo] = []

    func openProject(at path: String) async throws {}

    func updateCurrentFile(_ fileURL: URL?) {
        currentFileURL = fileURL?.standardizedFileURL
    }

    func updateOpenFiles(_ fileURLs: [URL]) {
        var uniqueURLs: [URL] = []
        for fileURL in fileURLs {
            let standardizedURL = fileURL.standardizedFileURL
            if !uniqueURLs.contains(standardizedURL) {
                uniqueURLs.append(standardizedURL)
            }
        }
        openFileURLs = uniqueURLs
    }

    func closeProject() async {
        currentProject = nil
        openFileURLs = []
        currentFileURL = nil
    }

    func refreshProjects() async throws {}
}
