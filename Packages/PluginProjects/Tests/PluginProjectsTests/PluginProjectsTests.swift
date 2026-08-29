import Foundation
import Testing
@testable import PluginProjects
import ProviderProject

@Suite("ProjectsStore")
@MainActor
struct ProjectsStoreTests {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("PluginProjectsTests-\(UUID().uuidString)")
    }

    @Test func projectsPersistenceRoundTrip() {
        let directory = temporaryDirectory()
        let store = ProjectsStore(pluginDirectory: directory)
        let project = ProjectEntry(name: "Demo", path: "/tmp/demo")

        store.save(projects: [project], currentProject: project)

        let reloaded = ProjectsStore(pluginDirectory: directory)
        let projects = reloaded.loadProjects()
        #expect(projects.count == 1)
        #expect(projects.first?.name == "Demo")
        #expect(reloaded.loadCurrentProjectPath() == "/tmp/demo")
    }

    @Test func openedFilesPersistenceRoundTrip() {
        let directory = temporaryDirectory()
        let store = ProjectsStore(pluginDirectory: directory)
        let file = URL(fileURLWithPath: "/tmp/demo/Sources/Main.swift")
        let opened = ProjectOpenedFiles(openFileURLs: [file], currentFileURL: file)

        store.saveOpenedFiles([ProjectsStore.normalizedPath("/tmp/demo"): opened])

        let reloaded = ProjectsStore(pluginDirectory: directory)
        #expect(reloaded.loadOpenedFiles()[ProjectsStore.normalizedPath("/tmp/demo")] == opened)
    }

    @Test func restoresAndPersistsOpenedFilesThroughProjectProviding() async throws {
        let firstProjectDirectory = temporaryDirectory()
        let secondProjectDirectory = temporaryDirectory()
        let storageDirectory = temporaryDirectory()
        let firstFile = firstProjectDirectory.appendingPathComponent("Sources/Main.swift")
        let secondFile = secondProjectDirectory.appendingPathComponent("Sources/App.swift")
        try FileManager.default.createDirectory(
            at: firstFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: secondFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "let value = 1\n".write(to: firstFile, atomically: true, encoding: .utf8)
        try "let value = 2\n".write(to: secondFile, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: firstProjectDirectory)
            try? FileManager.default.removeItem(at: secondProjectDirectory)
            try? FileManager.default.removeItem(at: storageDirectory)
        }

        let store = ProjectsStore(pluginDirectory: storageDirectory)
        let provider = DefaultProjectProvider()
        let persistence = ProjectOpenedFilesPersistence(project: provider, store: store)

        try await provider.openProject(at: firstProjectDirectory.path)
        provider.updateOpenFiles([firstFile])
        provider.updateCurrentFile(firstFile)
        try await provider.openProject(at: secondProjectDirectory.path)
        provider.updateOpenFiles([secondFile])
        provider.updateCurrentFile(secondFile)
        persistence.cancel()

        let reloadedProvider = DefaultProjectProvider()
        let reloadedPersistence = ProjectOpenedFilesPersistence(project: reloadedProvider, store: store)
        try await reloadedProvider.openProject(at: firstProjectDirectory.path)

        #expect(reloadedProvider.openFileURLs == [firstFile.standardizedFileURL])
        #expect(reloadedProvider.currentFileURL == firstFile.standardizedFileURL)

        try await reloadedProvider.openProject(at: secondProjectDirectory.path)

        #expect(reloadedProvider.openFileURLs == [secondFile.standardizedFileURL])
        #expect(reloadedProvider.currentFileURL == secondFile.standardizedFileURL)
        reloadedPersistence.cancel()
    }

    @Test func addProjectValidatesDirectory() throws {
        let directory = temporaryDirectory()
        let store = ProjectsStore(pluginDirectory: directory)

        #expect(throws: ProjectsStoreError.self) {
            _ = try store.add(path: "/nonexistent/\(UUID().uuidString)", to: [])
        }
    }

    /// 存储目录 key 为 "Projects"。
    @Test func storageDirectoryKeyIsProjects() {
        #expect(ProjectsPlugin.storageDirectoryKey == "Projects")
    }
}
