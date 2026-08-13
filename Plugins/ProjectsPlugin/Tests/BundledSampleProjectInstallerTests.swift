import Foundation
import Testing
@testable import ProjectsPlugin

@Suite(.serialized)
struct BundledSampleProjectInstallerTests {
    @Test @MainActor
    func installsEditableSampleForUninitializedStore() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }

        try fixture.installer.installIfNeeded(from: fixture.bundledProjectURL, into: fixture.store)

        let projects = fixture.store.loadProjects()
        let project = try #require(projects.first)
        #expect(projects.count == 1)
        #expect(project.name == "Lumi Sample")
        #expect(project.language == "javascript")
        #expect(fixture.store.loadCurrentProjectPath() == project.path)
        #expect(FileManager.default.fileExists(
            atPath: URL(fileURLWithPath: project.path).appendingPathComponent("index.html").path
        ))
        #expect(project.path.hasPrefix(fixture.store.pluginDirectory.path))
    }

    @Test @MainActor
    func doesNotReinstallAfterUserClearsProjectList() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        fixture.store.save(projects: [], currentProject: nil)

        try fixture.installer.installIfNeeded(from: fixture.bundledProjectURL, into: fixture.store)

        #expect(fixture.store.loadProjects().isEmpty)
        #expect(!FileManager.default.fileExists(
            atPath: fixture.store.pluginDirectory.appendingPathComponent("samples/Lumi Sample").path
        ))
    }
}

@MainActor
private struct Fixture {
    let rootURL: URL
    let bundledProjectURL: URL
    let store: ProjectsStore
    let installer = BundledSampleProjectInstaller()

    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectsPluginTests-\(UUID().uuidString)", isDirectory: true)
        bundledProjectURL = rootURL.appendingPathComponent("Bundle/Lumi Sample", isDirectory: true)
        try FileManager.default.createDirectory(
            at: bundledProjectURL,
            withIntermediateDirectories: true
        )
        try "sample".write(
            to: bundledProjectURL.appendingPathComponent("index.html"),
            atomically: true,
            encoding: .utf8
        )
        try "{}".write(
            to: bundledProjectURL.appendingPathComponent("package.json"),
            atomically: true,
            encoding: .utf8
        )
        store = ProjectsStore(pluginDirectory: rootURL.appendingPathComponent("Projects", isDirectory: true))
    }

    func remove() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}
