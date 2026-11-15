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
    ///
    /// 与 `DefaultProjectProvider` 一致：当前项目实际变化时发出
    /// `currentProjectChanged(_, reason:)`，供观察者追踪变更原因（#131）。
    private final class RecordingProjectProvider: ProjectProviding {
        var currentProject: ProjectInfo?
        var projects: [ProjectInfo] = []
        var openFileURLs: [URL] = []
        var currentFileURL: URL?
        var openedPaths: [String] = []
        private var pausedPath: String?
        private var pausedOpenStarted: CheckedContinuation<Void, Never>?
        private var resumePausedOpen: CheckedContinuation<Void, Never>?
        private var observers: [Observer] = []

        func pauseOpen(at path: String) {
            pausedPath = path
        }

        func waitForPausedOpen() async {
            await withCheckedContinuation { continuation in
                pausedOpenStarted = continuation
            }
        }

        func continuePausedOpen() {
            resumePausedOpen?.resume()
            resumePausedOpen = nil
        }

        func openProject(at path: String, reason: ProjectChangeReason) async throws {
            openedPaths.append(path)
            if path == pausedPath {
                await withCheckedContinuation { continuation in
                    resumePausedOpen = continuation
                    pausedOpenStarted?.resume()
                    pausedOpenStarted = nil
                }
            }
            let info = ProjectInfo(name: (path as NSString).lastPathComponent, path: path)
            let changed = currentProject?.path != info.path
            currentProject = info
            if changed {
                notify(.currentProjectChanged(info, reason: reason))
            }
        }

        func closeProject(reason: ProjectChangeReason) async {
            guard currentProject != nil else { return }
            currentProject = nil
            notify(.currentProjectChanged(nil, reason: reason))
        }
        func refreshProjects() async throws {}
        func updateCurrentFile(_ fileURL: URL?) { currentFileURL = fileURL }
        func updateOpenFiles(_ fileURLs: [URL]) { openFileURLs = fileURLs }
        func closeFile(_ fileURL: URL) { openFileURLs.removeAll { $0 == fileURL } }
        func synchronizeProjects(_ projects: [ProjectInfo]) {}

        @discardableResult
        func addObserver(_ callback: @escaping (ProjectProvidingEvent) -> Void) -> any ProjectProvidingObserverHandle {
            let observer = Observer(callback: callback)
            observers.append(observer)
            return observer
        }

        private func notify(_ event: ProjectProvidingEvent) {
            observers.removeAll { $0.isCancelled }
            for observer in observers {
                observer.invoke(event)
            }
        }

        private final class Observer: ProjectProvidingObserverHandle {
            private let callback: (ProjectProvidingEvent) -> Void
            fileprivate var isCancelled = false
            init(callback: @escaping (ProjectProvidingEvent) -> Void) { self.callback = callback }
            func cancel() { isCancelled = true }
            func invoke(_ event: ProjectProvidingEvent) {
                guard !isCancelled else { return }
                callback(event)
            }
        }
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

    @Test("项目切换尚未完成时快速选择另一对话，最终项目跟随最新选择")
    func rapidSelectionChangesSynchronizeLatestProject() async throws {
        let conversations = DefaultConversationManager()
        let firstID = try conversations.createConversation(
            title: "First",
            projectPath: "/tmp/project-first",
            providerID: nil,
            modelName: nil
        )
        let secondID = try conversations.createConversation(
            title: "Second",
            projectPath: "/tmp/project-second",
            providerID: nil,
            modelName: nil
        )
        let project = RecordingProjectProvider()
        project.pauseOpen(at: "/tmp/project-first")
        let observer = makeObserver(conversations: conversations, project: project)
        defer { observer.cancel() }

        conversations.selectConversation(id: firstID)
        await project.waitForPausedOpen()
        conversations.selectConversation(id: secondID)
        project.continuePausedOpen()

        for _ in 0..<50 where project.currentProject?.path != "/tmp/project-second" {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(project.openedPaths == ["/tmp/project-first", "/tmp/project-second"])
        #expect(project.currentProject?.path == "/tmp/project-second")
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

    @Test("外部打开的项目不会被随后到达的对话联动覆盖（#131）")
    func externalOpenSurvivesLateConversationSync() async throws {
        let conversations = DefaultConversationManager()
        let project = RecordingProjectProvider()
        // 绑定 cofficlab 的对话模拟「启动恢复的持久化选中对话」。
        let boundID = try conversations.createConversation(
            title: "Bound",
            projectPath: "/tmp/cofficlab",
            providerID: nil,
            modelName: nil
        )
        let observer = makeObserver(conversations: conversations, project: project)
        defer { observer.cancel() }

        // 外部打开 GitOK：当前项目变为 GitOK，reason=.externalOpen。
        try await project.openProject(at: "/tmp/gitok", reason: .externalOpen)
        project.openedPaths.removeAll()

        // 对话联动晚到：先取消再重新选中绑定对话，触发 conversationSwitch。
        conversations.deselectConversation()
        try await Task.sleep(for: .milliseconds(50))
        conversations.selectConversation(id: boundID)
        try await Task.sleep(for: .milliseconds(100))

        #expect(project.currentProject?.path == "/tmp/gitok", "外部打开的项目必须保留")
        #expect(project.openedPaths.isEmpty, "对话联动应让位，不得打开 cofficlab")
    }

    @Test("外部打开后用户主动选择项目会恢复对话联动（#131）")
    func userSelectedAfterExternalOpenReenablesSync() async throws {
        let conversations = DefaultConversationManager()
        let project = RecordingProjectProvider()
        let boundID = try conversations.createConversation(
            title: "Bound",
            projectPath: "/tmp/cofficlab",
            providerID: nil,
            modelName: nil
        )
        let observer = makeObserver(conversations: conversations, project: project)
        defer { observer.cancel() }

        try await project.openProject(at: "/tmp/gitok", reason: .externalOpen)
        // 用户主动打开项目（.userSelected）清除 externalOpen 让位状态。
        try await project.openProject(at: "/tmp/manual", reason: .userSelected)
        project.openedPaths.removeAll()

        conversations.deselectConversation()
        try await Task.sleep(for: .milliseconds(50))
        conversations.selectConversation(id: boundID)
        try await Task.sleep(for: .milliseconds(100))

        #expect(project.currentProject?.path == "/tmp/cofficlab", "用户主动选择后联动应恢复")
        #expect(project.openedPaths == ["/tmp/cofficlab"])
    }
}
