import Foundation
import ProviderConversation
import ProviderProject
import Testing
@testable import PluginProjects

/// 对话→项目联动（ConversationProjectSyncObserver）单元测试。
@MainActor
@Suite("Conversation project sync observer")
struct ConversationProjectSyncObserverTests {

    /// 记录 openProject 调用并持有当前项目的轻量替身。
    private final class RecordingProjectProvider: ProjectProviding {
        var currentProject: ProjectInfo?
        var projects: [ProjectInfo] = []
        var openFileURLs: [URL] = []
        var currentFileURL: URL?
        var openedPaths: [String] = []

        func openProject(at path: String) async throws {
            openedPaths.append(path)
            currentProject = ProjectInfo(name: (path as NSString).lastPathComponent, path: path)
        }

        func closeProject() async { currentProject = nil }
        func refreshProjects() async throws {}
        func updateCurrentFile(_ fileURL: URL?) { currentFileURL = fileURL }
        func updateOpenFiles(_ fileURLs: [URL]) { openFileURLs = fileURLs }
        func closeFile(_ fileURL: URL) { openFileURLs.removeAll { $0 == fileURL } }
        func synchronizeProjects(_ projects: [ProjectInfo]) {}
    }

    private func makeObserver(
        conversations: any ConversationManaging,
        project: RecordingProjectProvider
    ) -> ConversationProjectSyncObserver {
        ConversationProjectSyncObserver(conversations: conversations, project: project)
    }

    @Test("创建并选中绑定项目的对话会调用 openProject 切换到该对话的项目")
    func selectingConversationWithProjectOpensProject() async throws {
        let conversations = DefaultConversationManager()
        let project = RecordingProjectProvider()

        // 模拟真实插件已注册 observer 后再创建对话：createConversation 会
        // 自动选中新对话，observer 应捕获该变化并联动打开项目。
        let observer = makeObserver(conversations: conversations, project: project)
        defer { observer.cancel() }

        let conversationID = try conversations.createConversation(
            title: "A",
            projectPath: "/tmp/project-a",
            providerID: nil,
            modelName: nil
        )
        _ = conversationID
        try await Task.sleep(for: .milliseconds(100))

        #expect(project.openedPaths == ["/tmp/project-a"])
        #expect(project.currentProject?.path == "/tmp/project-a")
    }

    @Test("选中未绑定项目的对话不会打开任何项目")
    func selectingConversationWithoutProjectDoesNotOpen() async throws {
        let conversations = DefaultConversationManager()
        let project = RecordingProjectProvider()
        let conversationID = try conversations.createConversation(
            title: "A",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )

        let observer = makeObserver(conversations: conversations, project: project)
        defer { observer.cancel() }

        conversations.selectConversation(id: conversationID)
        try await Task.sleep(for: .milliseconds(100))

        #expect(project.openedPaths.isEmpty)
    }

    @Test("取消选中（nil）不会打开任何项目")
    func deselectDoesNotOpenProject() async throws {
        let conversations = DefaultConversationManager()
        let project = RecordingProjectProvider()
        let conversationID = try conversations.createConversation(
            title: "A",
            projectPath: "/tmp/project-a",
            providerID: nil,
            modelName: nil
        )

        let observer = makeObserver(conversations: conversations, project: project)
        defer { observer.cancel() }

        conversations.selectConversation(id: conversationID)
        try await Task.sleep(for: .milliseconds(100))
        project.openedPaths.removeAll()

        conversations.deselectConversation()
        try await Task.sleep(for: .milliseconds(100))

        #expect(project.openedPaths.isEmpty)
    }

    @Test("当前项目已等于对话绑定项目时不重复打开")
    func selectingAlreadyBoundProjectDoesNotReopen() async throws {
        let conversations = DefaultConversationManager()
        let project = RecordingProjectProvider()
        project.currentProject = ProjectInfo(name: "project-a", path: "/tmp/project-a")
        let conversationID = try conversations.createConversation(
            title: "A",
            projectPath: "/tmp/project-a",
            providerID: nil,
            modelName: nil
        )

        let observer = makeObserver(conversations: conversations, project: project)
        defer { observer.cancel() }

        conversations.selectConversation(id: conversationID)
        try await Task.sleep(for: .milliseconds(100))

        #expect(project.openedPaths.isEmpty)
    }

    @Test("切换选中到已存在的绑定项目对话会打开该项目")
    func selectingExistingConversationOpensProject() async throws {
        let conversations = DefaultConversationManager()
        let project = RecordingProjectProvider()

        // 先创建一个无项目对话并选中（确保后续切到有项目对话时值确实变化）。
        let noProjectID = try conversations.createConversation(
            title: "No Project",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )
        _ = noProjectID
        let boundID = try conversations.createConversation(
            title: "Bound",
            projectPath: "/tmp/project-b",
            providerID: nil,
            modelName: nil
        )

        let observer = makeObserver(conversations: conversations, project: project)
        defer { observer.cancel() }

        // 当前选中的是 boundID（最近创建自动选中）；先取消再用 select 切换回。
        conversations.deselectConversation()
        try await Task.sleep(for: .milliseconds(100))
        project.openedPaths.removeAll()

        conversations.selectConversation(id: boundID)
        try await Task.sleep(for: .milliseconds(100))

        #expect(project.openedPaths == ["/tmp/project-b"])
        #expect(project.currentProject?.path == "/tmp/project-b")
    }

    @Test("cancel 后不再响应选中变化")
    func cancelStopsObserving() async throws {
        let conversations = DefaultConversationManager()
        let project = RecordingProjectProvider()
        let conversationID = try conversations.createConversation(
            title: "A",
            projectPath: "/tmp/project-a",
            providerID: nil,
            modelName: nil
        )

        let observer = makeObserver(conversations: conversations, project: project)
        observer.cancel()

        conversations.selectConversation(id: conversationID)
        try await Task.sleep(for: .milliseconds(100))

        #expect(project.openedPaths.isEmpty)
    }
}