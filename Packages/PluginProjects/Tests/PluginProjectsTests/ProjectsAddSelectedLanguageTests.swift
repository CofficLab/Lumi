import Foundation
import ProviderProject
import Testing
@testable import PluginProjects

/// 模拟 `DefaultProjectProvider` 语义的记录桩：openProject 对不在列表中的
/// 路径补一个无语言条目，已存在的条目原样保留（含语言）。
@MainActor
private final class LanguagePreservingCapability: ProjectsProjectCapability {
    var projects: [ProjectInfo] = []
    var currentProject: ProjectInfo?
    private(set) var openedPaths: [String] = []

    func synchronizeProjects(_ projects: [ProjectInfo]) {
        self.projects = projects
    }

    func openProject(at path: String, reason: ProjectChangeReason) async throws {
        openedPaths.append(path)
        if let existing = projects.first(where: { $0.path == path }) {
            currentProject = existing
        } else {
            let info = ProjectInfo(
                name: URL(fileURLWithPath: path).lastPathComponent,
                path: path
            )
            projects.append(info)
            currentProject = info
        }
    }

    func closeProject(reason: ProjectChangeReason) async {
        currentProject = nil
    }
}

/// 通过 UI 添加并打开项目时不得丢弃 store 已探测到的语言（#477）。
@MainActor
@Suite("Projects 添加选中保留语言（#477）")
struct ProjectsAddSelectedLanguageTests {

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectsAddSelectedLanguage-\(UUID().uuidString)")
    }

    private func makeProjectDirectory(withPackageSwift: Bool) throws -> URL {
        let url = temporaryDirectory()
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        if withPackageSwift {
            try "// swift-tools-version:5.9\n".write(
                to: url.appendingPathComponent("Package.swift"),
                atomically: true,
                encoding: .utf8
            )
        }
        return url
    }

    @Test("select:true 打开新增项目时保留已检测的语言（**回归 #477**）")
    func addWithSelectKeepsDetectedLanguage() async throws {
        let pluginDir = temporaryDirectory()
        let projectDir = try makeProjectDirectory(withPackageSwift: true)
        defer {
            try? FileManager.default.removeItem(at: pluginDir)
            try? FileManager.default.removeItem(at: projectDir)
        }

        let store = ProjectsStore(pluginDirectory: pluginDir)
        let capability = LanguagePreservingCapability()
        let viewModel = ProjectsViewModel(store: store, projectCapability: capability)

        let added = try viewModel.add(path: projectDir.path, select: true)
        // openProject 经由 Task 异步派发，让出主 actor 使其有机会执行。
        try await Task.sleep(for: .milliseconds(50))

        #expect(added.language == "swift", "store 必须探测出 swift")
        #expect(capability.openedPaths == [added.path])
        #expect(
            capability.projects.first(where: { $0.path == added.path })?.language == "swift",
            "Provider 列表中的条目必须携带已检测语言"
        )
        #expect(
            capability.currentProject?.language == "swift",
            "打开后的当前项目必须携带已检测语言"
        )
    }

    @Test("select:true 对无特征文件的项目仍正常打开（语言为 nil）")
    func addWithSelectStillOpensPlainDirectory() async throws {
        let pluginDir = temporaryDirectory()
        let projectDir = try makeProjectDirectory(withPackageSwift: false)
        defer {
            try? FileManager.default.removeItem(at: pluginDir)
            try? FileManager.default.removeItem(at: projectDir)
        }

        let store = ProjectsStore(pluginDirectory: pluginDir)
        let capability = LanguagePreservingCapability()
        let viewModel = ProjectsViewModel(store: store, projectCapability: capability)

        let added = try viewModel.add(path: projectDir.path, select: true)
        try await Task.sleep(for: .milliseconds(50))

        #expect(added.language == nil)
        #expect(capability.openedPaths == [added.path])
        #expect(capability.currentProject?.path == added.path)
    }
}
