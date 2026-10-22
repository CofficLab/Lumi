import Foundation
import ProviderConversation
import ProviderGit
import ProviderMessage
import ProviderProject
import ProviderProjectRAG
import Testing
@testable import PluginMessageListEmpty

// MARK: - Stubs

/// `ProjectRAGProviding` 替身：只提供索引状态。
@MainActor
private final class StubRAGProvider: ProjectRAGProviding {
    var status: ProjectRAGIndexStatus?
    var isInitialized = true
    var currentProjectPath: String?
    /// 模拟「正在索引」：此时 indexStatus 仍会给出上一轮的旧值。
    var indexing = false

    func isIndexing(projectPath: String) -> Bool { indexing }

    func search(query: String, projectPath: String?, topK: Int) async throws -> ProjectRAGResponse {
        ProjectRAGResponse(query: query, results: [])
    }

    func ensureIndexed(projectPath: String, force: Bool, background: Bool) async throws {}

    func indexStatus(projectPath: String) async throws -> ProjectRAGIndexStatus? {
        status
    }
}

/// 消息统计替身：能区分「按会话过滤」与「不限会话」两种口径。
@MainActor
private final class ScopedMessageManager: MessageManaging {
    var globalSeries: [Date: Int] = [:]
    var scopedSeries: [Date: Int] = [:]
    /// 记录每次查询传入的会话集合。
    private(set) var queriedConversationIDs: [[String]?] = []

    func messages(for conversationID: UUID) -> [Message] { [] }
    func message(id: UUID, in conversationID: UUID) -> Message? { nil }
    func lastMessage(in conversationID: UUID) -> Message? { nil }
    func messageCount(for conversationID: UUID) -> Int { 0 }
    func insertMessage(_ message: Message, to conversationID: UUID) {}
    func updateMessage(id: UUID, in conversationID: UUID, content: String) {}
    func deleteMessage(id: UUID, in conversationID: UUID) {}
    func clearMessages(in conversationID: UUID) {}
    func updateToolCallResult(
        _ result: MessageToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        in conversationID: UUID,
        authorizationState: String?
    ) {}

    func dailyMessageCountsAsync(since: Date, conversationIDs: [String]?) async -> [Date: Int] {
        queriedConversationIDs.append(conversationIDs)
        guard let conversationIDs else { return globalSeries }
        return conversationIDs.isEmpty ? [:] : scopedSeries
    }

    func dailyTokenCountsAsync(since: Date, conversationIDs: [String]?) async -> [Date: Int] {
        guard let conversationIDs else { return globalSeries }
        return conversationIDs.isEmpty ? [:] : scopedSeries
    }
}

// MARK: - Tests

@MainActor
@Suite("Project context")
struct ProjectContextTests {
    /// 建一个临时项目目录，并写入给定文件名。
    private func makeProject(files: [String]) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-project-context-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        for file in files {
            try Data().write(to: url.appendingPathComponent(file))
        }
        return url
    }

    @Test("the home directory is folded into the displayed path")
    func homeDirectoryIsFolded() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        #expect(ProjectContextViewModel.abbreviatedPath(home) == "~")
        #expect(ProjectContextViewModel.abbreviatedPath(home + "/Code/app") == "~/Code/app")
        #expect(ProjectContextViewModel.abbreviatedPath("/tmp/other") == "/tmp/other")
    }

    @Test("the project type is detected from the manifest files")
    func detectsProjectType() async throws {
        let root = try makeProject(files: ["Package.swift", "README.md"])
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = DefaultProjectProvider()
        try await provider.openProject(at: root.path, reason: .userSelected)

        let model = ProjectContextViewModel(
            project: provider,
            conversations: nil,
            projectRAG: nil,
            git: nil
        )
        await model.loadIfNeeded()

        let identity = try #require(model.identity)
        #expect(identity.name == root.lastPathComponent)
        #expect(identity.typeLabels == ["Swift (Xcode / SPM)"])
        #expect(identity.typeSymbol == "swift")
    }

    @Test("a project without a manifest has no type label")
    func unknownTypeHasNoLabel() async throws {
        let root = try makeProject(files: ["notes.txt"])
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = DefaultProjectProvider()
        try await provider.openProject(at: root.path, reason: .userSelected)

        let model = ProjectContextViewModel(project: provider, conversations: nil, projectRAG: nil, git: nil)
        await model.loadIfNeeded()

        let identity = try #require(model.identity)
        #expect(identity.typeLabels.isEmpty)
        #expect(identity.typeSymbol == "folder")
    }

    @Test("the index row reports how many files were indexed")
    func indexRowAppears() async throws {
        let root = try makeProject(files: ["Package.swift"])
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = DefaultProjectProvider()
        try await provider.openProject(at: root.path, reason: .userSelected)

        let rag = StubRAGProvider()
        rag.status = ProjectRAGIndexStatus(
            projectPath: root.path,
            lastIndexedAt: Date().addingTimeInterval(-180),
            fileCount: 1_204,
            chunkCount: 3_000,
            isStale: false
        )

        let model = ProjectContextViewModel(project: provider, conversations: nil, projectRAG: rag, git: nil)
        await model.loadIfNeeded()

        let row = try #require(model.rows.first { $0.id == "index" })
        #expect(row.title.contains("1,204") || row.title.contains("1204"))
        #expect(row.action == .openFileTree)
        #expect(row.detail != nil, "索引时间缺失，就绪状态少了一半信息")
    }

    @Test("索引进行中时显示进行态，而不是上一轮的旧文件数")
    func indexingStateShowsProgress() async throws {
        let root = try makeProject(files: ["Package.swift"])
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = DefaultProjectProvider()
        try await provider.openProject(at: root.path, reason: .userSelected)

        let rag = StubRAGProvider()
        rag.status = ProjectRAGIndexStatus(
            projectPath: root.path,
            lastIndexedAt: Date().addingTimeInterval(-3_600),
            fileCount: 12,
            chunkCount: 30,
            isStale: true
        )

        let model = ProjectContextViewModel(project: provider, conversations: nil, projectRAG: rag, git: nil)
        await model.loadIfNeeded()
        #expect(model.rows.first { $0.id == "index" }?.title.contains("12") == true)

        // 索引跑起来时 status 还是旧值——显示它等于骗人。
        rag.indexing = true
        await model.loadIfNeeded(force: true)

        let row = try #require(model.rows.first { $0.id == "index" })
        #expect(!row.title.contains("12"), "索引进行中不该显示旧的文件数")
        #expect(row.action == .openFileTree)
        #expect(model.isLoading == false)
    }

    @Test("the git row only appears when there are uncommitted changes")    func gitRowFollowsTheWorkingTree() async throws {
        let root = try makeProject(files: ["Package.swift"])
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = DefaultProjectProvider()
        try await provider.openProject(at: root.path, reason: .userSelected)

        let git = InMemoryGitRepositoryReading()
        let model = ProjectContextViewModel(project: provider, conversations: nil, projectRAG: nil, git: git)
        await model.loadIfNeeded()
        #expect(model.rows.allSatisfy { $0.id != "git" }, "干净的仓库不该出现未提交改动行")

        git.setStatus(
            GitStatus(branch: "main", modified: ["a.swift", "b.swift"]),
            forPath: root.path
        )
        await model.loadIfNeeded(force: true)

        let row = try #require(model.rows.first { $0.id == "git" })
        #expect(row.title.contains("2"))
        #expect(row.action == .openGit)
    }

    @Test("the last conversation row points at the most recent conversation")
    func lastConversationRowAppears() async throws {
        let root = try makeProject(files: ["Package.swift"])
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = DefaultProjectProvider()
        try await provider.openProject(at: root.path, reason: .userSelected)

        let conversations = DefaultConversationManager()
        _ = try conversations.createConversation(title: "旧会话", projectPath: root.path, providerID: nil, modelName: nil)
        let recent = try conversations.createConversation(title: "修复登录跳转", projectPath: root.path, providerID: nil, modelName: nil)

        let model = ProjectContextViewModel(
            project: provider,
            conversations: conversations,
            projectRAG: nil,
            git: nil
        )
        await model.loadIfNeeded()

        let row = try #require(model.rows.first { $0.id == "last-conversation" })
        #expect(row.title.contains("修复登录跳转"))
        #expect(row.action == .resumeConversation(recent))
    }

    @Test("the details report how many conversations the project has")
    func detailsReportConversationCount() async throws {
        let root = try makeProject(files: ["Package.swift"])
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = DefaultProjectProvider()
        try await provider.openProject(at: root.path, reason: .userSelected)

        let conversations = DefaultConversationManager()
        _ = try conversations.createConversation(title: "A", projectPath: root.path, providerID: nil, modelName: nil)
        _ = try conversations.createConversation(title: "B", projectPath: root.path, providerID: nil, modelName: nil)
        _ = try conversations.createConversation(title: "C", projectPath: "/other/project", providerID: nil, modelName: nil)

        let model = ProjectContextViewModel(
            project: provider,
            conversations: conversations,
            projectRAG: nil,
            git: nil
        )
        await model.loadIfNeeded()

        let detail = try #require(model.details.first { $0.id == "conversation-count" })
        #expect(detail.value.contains("2"), "别的项目的会话不该被算进来")
    }

    @Test("notable entry files become labels")
    func notableFilesBecomeLabels() async throws {
        let root = try makeProject(files: ["Package.swift", "README.md", "AGENTS.md", "random.bin"])
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = DefaultProjectProvider()
        try await provider.openProject(at: root.path, reason: .userSelected)

        let model = ProjectContextViewModel(project: provider, conversations: nil, projectRAG: nil, git: nil)
        await model.loadIfNeeded()

        #expect(model.keyFiles.contains("Package.swift"))
        #expect(model.keyFiles.contains("README.md"))
        #expect(model.keyFiles.contains("AGENTS.md"))
        #expect(!model.keyFiles.contains("random.bin"), "无关文件不该出现在标签里")
    }

    @Test("without a project everything is cleared")
    func noProjectClearsEverything() async throws {
        let provider = DefaultProjectProvider()
        let model = ProjectContextViewModel(project: provider, conversations: nil, projectRAG: nil, git: nil)
        await model.loadIfNeeded()

        #expect(model.identity == nil)
        #expect(model.rows.isEmpty)
        #expect(model.details.isEmpty)
        #expect(model.hasProject == false)
    }
}

@MainActor
@Suite("Activity scope")
struct ActivityScopeTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ offsetFromToday: Int) -> Date {
        let today = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .day, value: offsetFromToday, to: today)!
    }

    @Test("the project scope filters the statistics by the project's conversations")
    func projectScopeFiltersByConversation() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-scope-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = DefaultProjectProvider()
        try await provider.openProject(at: root.path, reason: .userSelected)

        let conversations = DefaultConversationManager()
        let id = try conversations.createConversation(title: "项目内会话", projectPath: root.path, providerID: nil, modelName: nil)

        let manager = ScopedMessageManager()
        manager.globalSeries = [day(0): 100]
        manager.scopedSeries = [day(0): 7]

        let context = ProjectContextViewModel(
            project: provider,
            conversations: conversations,
            projectRAG: nil,
            git: nil
        )
        let model = EmptyStateActivityViewModel(
            messages: manager,
            projectContext: context,
            calendar: calendar
        )

        await model.loadIfNeeded()

        #expect(model.effectiveScope == .project)
        #expect(model.totalMessages == 7, "项目维度必须只统计这个项目的消息")
        let queried = try #require(manager.queriedConversationIDs.first)
        #expect(queried == [id.uuidString])
    }

    @Test("without a project the scope falls back to the global statistics")
    func fallsBackToGlobalWithoutProject() async throws {
        let manager = ScopedMessageManager()
        manager.globalSeries = [day(0): 42]

        let provider = DefaultProjectProvider()
        let context = ProjectContextViewModel(
            project: provider,
            conversations: nil,
            projectRAG: nil,
            git: nil
        )
        let model = EmptyStateActivityViewModel(
            messages: manager,
            projectContext: context,
            calendar: calendar
        )

        await model.loadIfNeeded()

        #expect(model.effectiveScope == .all)
        #expect(model.totalMessages == 42)
        #expect(model.canSwitchScope == false, "没有项目时不该提供范围切换")
    }

    @Test("the project scope stays visible even when the project has no history")
    func projectScopeStaysVisibleWithoutActivity() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-scope-empty-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = DefaultProjectProvider()
        try await provider.openProject(at: root.path, reason: .userSelected)

        let conversations = DefaultConversationManager()
        let manager = ScopedMessageManager()

        let context = ProjectContextViewModel(
            project: provider,
            conversations: conversations,
            projectRAG: nil,
            git: nil
        )
        let model = EmptyStateActivityViewModel(
            messages: manager,
            projectContext: context,
            calendar: calendar
        )

        await model.loadIfNeeded()

        #expect(model.totalMessages == 0)
        #expect(model.hasActivity == false)
        #expect(model.isVisible, "项目维度没有历史也是一条信息，不该整块消失")
        #expect(model.hasChartData == false)
    }

    @Test("switching the scope reloads the window with the other statistics")
    func switchingScopeReloads() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-scope-switch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = DefaultProjectProvider()
        try await provider.openProject(at: root.path, reason: .userSelected)

        let conversations = DefaultConversationManager()
        _ = try conversations.createConversation(title: "项目内会话", projectPath: root.path, providerID: nil, modelName: nil)

        let manager = ScopedMessageManager()
        manager.globalSeries = [day(0): 100]
        manager.scopedSeries = [day(0): 7]

        let context = ProjectContextViewModel(
            project: provider,
            conversations: conversations,
            projectRAG: nil,
            git: nil
        )
        let model = EmptyStateActivityViewModel(
            messages: manager,
            projectContext: context,
            calendar: calendar
        )

        await model.loadIfNeeded()
        #expect(model.totalMessages == 7)

        await model.setScope(.all)
        #expect(model.effectiveScope == .all)
        #expect(model.totalMessages == 100)

        await model.setScope(.project)
        #expect(model.effectiveScope == .project)
        #expect(model.totalMessages == 7)
    }
}
