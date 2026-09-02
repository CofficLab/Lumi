import Foundation
import ProviderConversation
import ProviderProject
import Testing
@testable import PluginConversationManager

/// 选中对话联动当前项目（Conversation → Project）的单元测试。
@MainActor
@Suite("Conversation project sync")
struct ConversationProjectSyncTests {

    /// 记录 openProject 调用并持有当前项目的轻量替身。
    private final class RecordingProjectProvider: ProjectProviding {
        var currentProject: ProjectInfo?
        var projects: [ProjectInfo] = []
        var openFileURLs: [URL] = []
        var currentFileURL: URL?
        /// 每次 openProject(at:) 的调用路径，用于断言。
        var openedPaths: [String] = []

        func openProject(at path: String) async throws {
            openedPaths.append(path)
            currentProject = ProjectInfo(name: (path as NSString).lastPathComponent, path: path)
        }

        func closeProject() async {
            currentProject = nil
        }

        func refreshProjects() async throws {}

        func updateCurrentFile(_ fileURL: URL?) { currentFileURL = fileURL }
        func updateOpenFiles(_ fileURLs: [URL]) { openFileURLs = fileURLs }
        func closeFile(_ fileURL: URL) { openFileURLs.removeAll { $0 == fileURL } }
        func synchronizeProjects(_ projects: [ProjectInfo]) {}
    }

    private func makeManager(
        project: (any ProjectProviding)?,
        conversations: [ConversationSummary]
    ) -> ConversationManager {
        let manager = ConversationManager(
            store: nil,
            dataDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("lumi-conversation-project-sync-\(UUID().uuidString)", isDirectory: true),
            project: project
        )
        manager.conversations = conversations
        return manager
    }

    @Test("选中绑定项目的对话会调用 openProject 切换到该对话的项目")
    func selectingConversationWithProjectOpensProject() async throws {
        let project = RecordingProjectProvider()
        let conversationID = UUID()
        let manager = makeManager(
            project: project,
            conversations: [
                ConversationSummary(id: conversationID, title: "A", projectPath: "/tmp/project-a"),
            ]
        )

        manager.selectConversation(id: conversationID)
        // 联动是异步 fire-and-forget；给 Task 机会执行。
        try await Task.sleep(for: .milliseconds(100))

        #expect(project.openedPaths == ["/tmp/project-a"])
        #expect(project.currentProject?.path == "/tmp/project-a")
    }

    @Test("选中未绑定项目的对话不会打开任何项目")
    func selectingConversationWithoutProjectDoesNotOpen() async throws {
        let project = RecordingProjectProvider()
        let conversationID = UUID()
        let manager = makeManager(
            project: project,
            conversations: [
                ConversationSummary(id: conversationID, title: "A", projectPath: nil),
            ]
        )

        manager.selectConversation(id: conversationID)
        try await Task.sleep(for: .milliseconds(100))

        #expect(project.openedPaths.isEmpty)
    }

    @Test("选中无对话（nil）不会打开任何项目")
    func deselectDoesNotOpenProject() async throws {
        let project = RecordingProjectProvider()
        let conversationID = UUID()
        let manager = makeManager(
            project: project,
            conversations: [
                ConversationSummary(id: conversationID, title: "A", projectPath: "/tmp/project-a"),
            ]
        )
        // 先建立选中，再取消。
        manager.selectConversation(id: conversationID)
        try await Task.sleep(for: .milliseconds(100))
        project.openedPaths.removeAll()

        manager.deselectConversation()
        try await Task.sleep(for: .milliseconds(100))

        #expect(project.openedPaths.isEmpty)
        #expect(manager.selectedConversationID == nil)
    }

    @Test("当前项目已等于对话绑定项目时不重复打开")
    func selectingAlreadyBoundProjectDoesNotReopen() async throws {
        let project = RecordingProjectProvider()
        project.currentProject = ProjectInfo(name: "project-a", path: "/tmp/project-a")
        let conversationID = UUID()
        let manager = makeManager(
            project: project,
            conversations: [
                ConversationSummary(id: conversationID, title: "A", projectPath: "/tmp/project-a"),
            ]
        )

        manager.selectConversation(id: conversationID)
        try await Task.sleep(for: .milliseconds(100))

        #expect(project.openedPaths.isEmpty)
    }

    @Test("没有 ProjectProviding 时选中对话不崩溃")
    func selectingWithoutProjectProviderIsSafe() async throws {
        let conversationID = UUID()
        let manager = makeManager(
            project: nil,
            conversations: [
                ConversationSummary(id: conversationID, title: "A", projectPath: "/tmp/project-a"),
            ]
        )

        manager.selectConversation(id: conversationID)
        try await Task.sleep(for: .milliseconds(100))

        #expect(manager.selectedConversationID == conversationID)
    }
}