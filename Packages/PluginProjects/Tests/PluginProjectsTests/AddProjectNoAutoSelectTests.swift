import Foundation
import ProviderProject
import Testing
@testable import PluginProjects

/// 记录 openProject/closeProject 调用的项目能力桩，用于断言 add_project 的选中契约。
@MainActor
private final class RecordingProjectsCapability: ProjectsProjectCapability {
    var projects: [ProjectInfo] = []
    var currentProject: ProjectInfo?
    private(set) var openedPaths: [String] = []
    private(set) var closeCount = 0

    func synchronizeProjects(_ projects: [ProjectInfo]) {
        self.projects = projects
    }

    func openProject(at path: String, reason: ProjectChangeReason) async throws {
        openedPaths.append(path)
        currentProject = ProjectInfo(
            name: URL(fileURLWithPath: path).lastPathComponent,
            path: path,
            language: nil
        )
    }

    func closeProject(reason: ProjectChangeReason) async {
        currentProject = nil
        closeCount += 1
    }
}

/// add_project 声明「不切换当前项目」（select:false）。即使当前无项目，
/// 也只入列、不得自动打开，否则文档与实际行为相反（#475）。
@MainActor
@Suite("AddProjectNoAutoSelect（#475）")
struct AddProjectNoAutoSelectTests {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("AddProjectNoAutoSelect-\(UUID().uuidString)")
    }

    private func makeProjectDirectory() throws -> URL {
        let url = temporaryDirectory()
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("select:false 且当前无项目时只入列、不得自动打开项目")
    func addWithoutSelectDoesNotOpenWhenNoCurrentProject() async throws {
        let pluginDir = temporaryDirectory()
        let projectDir = try makeProjectDirectory()
        defer {
            try? FileManager.default.removeItem(at: pluginDir)
            try? FileManager.default.removeItem(at: projectDir)
        }

        let store = ProjectsStore(pluginDirectory: pluginDir)
        let capability = RecordingProjectsCapability()
        let viewModel = ProjectsViewModel(store: store, projectCapability: capability)

        _ = try viewModel.add(path: projectDir.path, select: false)
        // openProject 经由 Task 异步派发，让出主 actor 使其有机会执行。
        try await Task.sleep(for: .milliseconds(50))

        #expect(capability.openedPaths.isEmpty, "select:false 不得自动打开项目")
        #expect(capability.currentProject == nil, "必须保持「无项目」选中态")
        #expect(capability.projects.count == 1, "新项目仍应入列")
    }

    @Test("select:false 保留已有当前项目，不打开新增项目")
    func addWithoutSelectPreservesExistingCurrentProject() async throws {
        let pluginDir = temporaryDirectory()
        let projectDir = try makeProjectDirectory()
        defer {
            try? FileManager.default.removeItem(at: pluginDir)
            try? FileManager.default.removeItem(at: projectDir)
        }

        let store = ProjectsStore(pluginDirectory: pluginDir)
        let capability = RecordingProjectsCapability()
        let existing = ProjectInfo(name: "existing", path: "/tmp/existing-project", language: nil)
        capability.projects = [existing]
        capability.currentProject = existing
        let viewModel = ProjectsViewModel(store: store, projectCapability: capability)

        _ = try viewModel.add(path: projectDir.path, select: false)
        try await Task.sleep(for: .milliseconds(50))

        #expect(capability.openedPaths.isEmpty, "已有当前项目时更不得打开新项目")
        #expect(capability.currentProject?.path == existing.path, "当前项目必须保持不变")
        #expect(capability.projects.count == 2, "新项目入列但不取代当前项目")
    }

    @Test("select:true 仍会打开新增项目")
    func addWithSelectStillOpensAddedProject() async throws {
        let pluginDir = temporaryDirectory()
        let projectDir = try makeProjectDirectory()
        defer {
            try? FileManager.default.removeItem(at: pluginDir)
            try? FileManager.default.removeItem(at: projectDir)
        }

        let store = ProjectsStore(pluginDirectory: pluginDir)
        let capability = RecordingProjectsCapability()
        let viewModel = ProjectsViewModel(store: store, projectCapability: capability)

        let added = try viewModel.add(path: projectDir.path, select: true)
        try await Task.sleep(for: .milliseconds(50))

        #expect(capability.openedPaths == [added.path], "select:true 必须打开新增项目")
        #expect(capability.currentProject?.path == added.path)
    }
}