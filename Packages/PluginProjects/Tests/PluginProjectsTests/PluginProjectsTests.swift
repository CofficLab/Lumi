import Foundation
import Testing
@testable import PluginProjects

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
