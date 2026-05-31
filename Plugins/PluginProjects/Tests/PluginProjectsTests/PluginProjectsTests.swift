import Foundation
import LumiCoreKit
import Testing
@testable import PluginProjects

@Test func branchDisplayNameIgnoresMissingAndBlankValues() async throws {
    #expect(GitBranchCache.displayName(for: nil) == nil)
    #expect(GitBranchCache.displayName(for: "") == nil)
    #expect(GitBranchCache.displayName(for: " \n\t ") == nil)
    #expect(GitBranchCache.displayName(for: "  main\n") == "main")
}

@Test func addProjectToolTrimsCopiedPathWhitespace() {
    #expect(AddProjectTool.normalizedPath(from: " \n/Users/example/Project\t") == "/Users/example/Project")
}

@Test func addProjectToolRejectsBlankCopiedPath() {
    #expect(AddProjectTool.normalizedPath(from: " \n\t ") == nil)
}

@Test func listProjectsToolClampsLimitBeforePrefixingProjects() {
    #expect(ListProjectsTool.normalizedLimit(nil) == 5)
    #expect(ListProjectsTool.normalizedLimit(-10) == 1)
    #expect(ListProjectsTool.normalizedLimit(0) == 1)
    #expect(ListProjectsTool.normalizedLimit(25) == 25)
    #expect(ListProjectsTool.normalizedLimit(25.0) == 25)
    #expect(ListProjectsTool.normalizedLimit("25") == 25)
    #expect(ListProjectsTool.normalizedLimit(999) == 500)
    #expect(ListProjectsTool.normalizedLimit("not-a-number") == 5)
}

@Test func projectsStoreQuarantinesInvalidStateFileAndRecovers() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ProjectsStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let settingsDirectory = root
        .appendingPathComponent("Projects", isDirectory: true)
        .appendingPathComponent("settings", isDirectory: true)
    try FileManager.default.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)

    let stateURL = settingsDirectory.appendingPathComponent("projects.json")
    let corruptURL = settingsDirectory.appendingPathComponent("projects.corrupt.json")
    let invalidData = Data("not json".utf8)
    try invalidData.write(to: stateURL)

    let store = ProjectsStore(dbFolderURLProvider: { root })

    #expect(store.loadProjects().isEmpty)
    #expect((try? Data(contentsOf: corruptURL)) == invalidData)

    let project = Project(name: "Lumi", path: "/tmp/Lumi", lastUsed: Date(timeIntervalSince1970: 1_700_000_000))
    store.saveProjects([project])

    let reloaded = try await loadProjectsEventually(from: stateURL)
    #expect(reloaded.count == 1)
    #expect(reloaded.first?.name == project.name)
    #expect(reloaded.first?.path == project.path)
    #expect(reloaded.first?.lastUsed == project.lastUsed)
}

private func loadProjectsEventually(from stateURL: URL) async throws -> [Project] {
    for _ in 0..<50 {
        if let data = try? Data(contentsOf: stateURL),
           let projects = try? JSONDecoder().decode([Project].self, from: data) {
            return projects
        }
        try await Task.sleep(for: .milliseconds(20))
    }

    let data = try Data(contentsOf: stateURL)
    return try JSONDecoder().decode([Project].self, from: data)
}
