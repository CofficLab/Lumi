import Foundation
import ProviderConversation
import ProviderProject
import Testing

@testable import PluginConversationManager

/// #625 回归：创建对话时的项目绑定必须是显式意图。
///
/// 生产实现历史上把 `projectPath: nil` 解释成「沿用当前项目」，无项目
/// 对话分叉时无法表达「明确无项目」。`ProjectBinding` 把三种意图分开，
/// 这些用例锁定 `.none` 不回退、`.inheritCurrent` 保持旧行为，以及空
/// 字符串不会落入数据层。
@MainActor
@Suite("对话项目绑定")
struct ConversationProjectBindingTests {
    private func makeManager(currentProjectPath: String?) -> ConversationManager {
        let project = StubProjectProvider()
        if let currentProjectPath {
            project.currentProject = ProjectInfo(name: "current", path: currentProjectPath)
        }
        return ConversationManager(
            store: nil,
            dataDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("ConversationProjectBinding-\(UUID().uuidString)", isDirectory: true),
            project: project
        )
    }

    @Test("显式 .none 不会回退到当前项目")
    func noneDoesNotFallBackToCurrentProject() throws {
        let manager = makeManager(currentProjectPath: "/tmp/current-project")

        let id = try manager.createConversation(
            title: "无项目对话",
            binding: .none,
            providerID: nil,
            modelName: nil
        )

        #expect(manager.conversations.first { $0.id == id }?.projectPath == nil)
    }

    @Test(".inheritCurrent 沿用当前项目")
    func inheritCurrentUsesCurrentProject() throws {
        let manager = makeManager(currentProjectPath: "/tmp/current-project")

        let id = try manager.createConversation(
            title: "当前项目对话",
            binding: .inheritCurrent,
            providerID: nil,
            modelName: nil
        )

        #expect(manager.conversations.first { $0.id == id }?.projectPath == "/tmp/current-project")
    }

    @Test(".project 使用指定项目并覆盖当前项目")
    func explicitProjectOverridesCurrent() throws {
        let manager = makeManager(currentProjectPath: "/tmp/current-project")

        let id = try manager.createConversation(
            title: "指定项目对话",
            binding: .project("/tmp/source-project"),
            providerID: nil,
            modelName: nil
        )

        #expect(manager.conversations.first { $0.id == id }?.projectPath == "/tmp/source-project")
    }

    @Test("旧接口 projectPath: nil 仍沿用当前项目")
    func legacyNilStillInheritsCurrentProject() throws {
        let manager = makeManager(currentProjectPath: "/tmp/current-project")

        let id = try manager.createConversation(
            title: "旧接口对话",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )

        #expect(manager.conversations.first { $0.id == id }?.projectPath == "/tmp/current-project")
    }

    @Test("空字符串项目标识不会写入数据层")
    func emptyProjectPathIsNeverStored() throws {
        let manager = makeManager(currentProjectPath: "/tmp/current-project")

        let viaBinding = try manager.createConversation(
            title: "空绑定",
            binding: .project(""),
            providerID: nil,
            modelName: nil
        )
        #expect(manager.conversations.first { $0.id == viaBinding }?.projectPath == nil)

        let viaLegacy = try manager.createConversation(
            title: "空旧接口",
            projectPath: "",
            providerID: nil,
            modelName: nil
        )
        #expect(manager.conversations.first { $0.id == viaLegacy }?.projectPath == nil)
    }
}

/// 测试替身：只提供当前项目，供绑定解析使用。
@MainActor
private final class StubProjectProvider: ProjectProviding {
    var currentProject: ProjectInfo?
    var projects: [ProjectInfo] = []
    var openFileURLs: [URL] = []
    var currentFileURL: URL?

    func openProject(at path: String, reason: ProjectChangeReason) async throws {
        currentProject = ProjectInfo(name: (path as NSString).lastPathComponent, path: path)
    }
    func closeProject(reason: ProjectChangeReason) async { currentProject = nil }
    func refreshProjects() async throws {}
    func updateCurrentFile(_ fileURL: URL?) { currentFileURL = fileURL }
    func updateOpenFiles(_ fileURLs: [URL]) { openFileURLs = fileURLs }
    func closeFile(_ fileURL: URL) { openFileURLs.removeAll { $0 == fileURL } }
    func synchronizeProjects(_ projects: [ProjectInfo]) {}
    func previewFile(_ fileURL: URL) { updateCurrentFile(fileURL) }
    func pinFile(_ fileURL: URL) { updateCurrentFile(fileURL) }
    func activateFile(_ fileURL: URL) { updateCurrentFile(fileURL) }
}
