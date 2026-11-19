import Foundation
import ProviderActivityBar
import ProviderConversation
import ProviderGit
import ProviderMessage
import ProviderPluginControl
import ProviderProject
import ProviderProjectRAG
import ProviderRailView
import SwiftUI
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

/// 能把 `indexStatus` 挂起的 RAG 替身。
///
/// 用于确定性地制造「加载仍在途」的窗口：真实链路里目录读取、索引状态、
/// Git 状态都可能迟迟不返回，靠 sleep 猜时序不可靠，这里用 continuation
/// 把窗口固定住。
@MainActor
private final class GatedRAGProvider: ProjectRAGProviding {
    var status: ProjectRAGIndexStatus?
    var isInitialized = true
    var currentProjectPath: String?

    /// 已进入 `indexStatus` 的次数。
    private(set) var indexStatusCallCount = 0

    /// 闸门开关：为 true 时 `indexStatus` 会挂起直到 `release()`。
    private var isGated = false
    /// 挂起中的 continuation。
    private var waiter: CheckedContinuation<Void, Never>?

    func isIndexing(projectPath: String) -> Bool { false }

    func search(query: String, projectPath: String?, topK: Int) async throws -> ProjectRAGResponse {
        ProjectRAGResponse(query: query, results: [])
    }

    func ensureIndexed(projectPath: String, force: Bool, background: Bool) async throws {}

    func indexStatus(projectPath: String) async throws -> ProjectRAGIndexStatus? {
        indexStatusCallCount += 1
        if isGated {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                waiter = continuation
            }
        }
        return status
    }

    /// 让 `indexStatus` 挂起，直到 `release()` 被调用。
    func gate() {
        isGated = true
    }

    /// 放行挂起的查询。
    func release() {
        isGated = false
        waiter?.resume()
        waiter = nil
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

// MARK: - Navigation stubs

/// 记录跨插件跳转的调用顺序，用于断言「先切 Chat、再选文件树」。
@MainActor
private final class NavigationRecorder {
    var events: [String] = []
}

@MainActor
private final class RecordingActivityBar: ActivityBarProviding {
    let recorder: NavigationRecorder
    var items: [ActivityBarItem] = []

    init(recorder: NavigationRecorder) {
        self.recorder = recorder
    }

    func registerItems(_ items: [ActivityBarItem]) {
        self.items = items
    }

    func activateItem(id: String?) {
        guard let id else { return }
        recorder.events.append("activity:\(id)")
    }

    func makeActivityBarView() -> AnyView { AnyView(EmptyView()) }
}

@MainActor
private final class RecordingRail: RailViewProviding {
    let recorder: NavigationRecorder
    var tabs: [RailTabItem] = []

    init(recorder: NavigationRecorder) {
        self.recorder = recorder
    }

    func registerTabs(_ tabs: [RailTabItem]) {
        self.tabs = tabs
    }

    func activateTab(id: String?) {
        guard let id else { return }
        recorder.events.append("tab:\(id)")
    }

    func activateTabWhenAvailable(id: String?) {
        activateTab(id: id)
    }

    func makeRailView() -> AnyView { AnyView(EmptyView()) }
}

/// 插件启停替身：启用成功后模拟插件 `onBoot` 注册 Activity Bar 入口。
@MainActor
private final class RecordingPluginControl: PluginControlling {
    let recorder: NavigationRecorder
    let activityBar: RecordingActivityBar?
    let succeeds: Bool
    private(set) var enabledIDs: [String] = []

    init(recorder: NavigationRecorder, activityBar: RecordingActivityBar? = nil, succeeds: Bool = true) {
        self.recorder = recorder
        self.activityBar = activityBar
        self.succeeds = succeeds
    }

    var lastErrorDescription: String? { succeeds ? nil : "enable failed" }

    func enablePlugin(id: String) async -> Bool {
        enabledIDs.append(id)
        recorder.events.append("enable:\(id)")
        guard succeeds else { return false }
        if let activityBar,
           !activityBar.items.contains(where: { $0.ownerPluginID == id }) {
            activityBar.registerItems(activityBar.items + [
                ActivityBarItem(
                    id: "\(id).entry",
                    title: "Git",
                    systemImage: "arrow.triangle.branch",
                    ownerPluginID: id
                )
            ])
        }
        return true
    }

    func disablePlugin(id: String) async -> Bool { false }

    func isEnabled(id: String) -> Bool { enabledIDs.contains(id) }
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

    // MARK: - #808 Git 改动计数：含未跟踪、按路径去重

    @Test func untrackedOnlyRepositoryShowsOneChangedFile() async throws {
        let root = try makeProject(files: ["Package.swift"])
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = DefaultProjectProvider()
        try await provider.openProject(at: root.path, reason: .userSelected)

        let git = InMemoryGitRepositoryReading()
        // 只有一个未跟踪文件：旧实现漏掉 untracked，算出 0 → 根本不渲染 Git 行（#808）。
        git.setStatus(GitStatus(branch: "main", untracked: ["new.swift"]), forPath: root.path)

        let model = ProjectContextViewModel(project: provider, conversations: nil, projectRAG: nil, git: git)
        await model.loadIfNeeded()

        let row = try #require(model.rows.first { $0.id == "git" }, "未跟踪文件也算未提交改动，必须出现 Git 行")
        #expect(row.title.contains("1"))
        #expect(row.action == .openGit)
    }

    @Test func partiallyStagedFileCountsOnce() async throws {
        let root = try makeProject(files: ["Package.swift"])
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = DefaultProjectProvider()
        try await provider.openProject(at: root.path, reason: .userSelected)

        let git = InMemoryGitRepositoryReading()
        // 同一文件既在暂存区又有未暂存改动：是一个路径，不是两个（#808）。
        git.setStatus(
            GitStatus(branch: "main", modified: ["a.swift"], staged: ["a.swift"]),
            forPath: root.path
        )

        let model = ProjectContextViewModel(project: provider, conversations: nil, projectRAG: nil, git: git)
        await model.loadIfNeeded()

        let row = try #require(model.rows.first { $0.id == "git" })
        #expect(row.title.contains("1"), "部分暂存的同一文件只能算一个")
        #expect(!row.title.contains("2"), "不得把同一路径重复计数")
    }

    @Test func allBucketsAreMergedAndDeduplicated() async throws {
        let root = try makeProject(files: ["Package.swift"])
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = DefaultProjectProvider()
        try await provider.openProject(at: root.path, reason: .userSelected)

        let git = InMemoryGitRepositoryReading()
        // 六个桶都覆盖：m 同时在 modified 与 staged（去重），u1/u2 是未跟踪。
        // 唯一路径 {m,a,d,r,s,u1,u2} = 7；旧实现累加各桶得 6（漏未跟踪、重复 m）。
        git.setStatus(
            GitStatus(
                branch: "main",
                modified: ["m"],
                added: ["a"],
                deleted: ["d"],
                renamed: ["r"],
                staged: ["m", "s"],
                untracked: ["u1", "u2"]
            ),
            forPath: root.path
        )

        let model = ProjectContextViewModel(project: provider, conversations: nil, projectRAG: nil, git: git)
        await model.loadIfNeeded()

        let row = try #require(model.rows.first { $0.id == "git" })
        #expect(row.title.contains("7"), "应合并所有桶并按路径去重")
    }

    @Test func cleanStatusShowsNoGitRow() async throws {
        let root = try makeProject(files: ["Package.swift"])
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = DefaultProjectProvider()
        try await provider.openProject(at: root.path, reason: .userSelected)

        let git = InMemoryGitRepositoryReading()
        // 真正干净的状态（能读到、各桶皆空）：不得渲染「0 个文件改动」的行。
        git.setStatus(GitStatus(branch: "main"), forPath: root.path)

        let model = ProjectContextViewModel(project: provider, conversations: nil, projectRAG: nil, git: git)
        await model.loadIfNeeded()

        #expect(model.rows.allSatisfy { $0.id != "git" }, "干净仓库不该出现未提交改动行")
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

    // MARK: - #807 会话增删后项目卡缓存必须重读

    /// 会话 CRUD 不经过项目切换路径，卡片把会话数与最近会话连同项目身份
    /// 一起缓存；不作废的话，同一项目的非强制加载永远短路返回旧数据。
    /// 插件在 CRUD 事件里调用 `invalidateConversationData()`，回到空态时
    /// 视图的 `.task` 只做非强制加载，缓存必须在这次加载里重读。
    @Test("会话增删后非强制加载重读会话数与最近会话")
    func conversationCRUDInvalidatesCardCache() async throws {
        let root = try makeProject(files: ["Package.swift"])
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = DefaultProjectProvider()
        try await provider.openProject(at: root.path, reason: .userSelected)

        let conversations = DefaultConversationManager()
        let a = try conversations.createConversation(title: "A", projectPath: root.path, providerID: nil, modelName: nil)

        let model = ProjectContextViewModel(
            project: provider,
            conversations: conversations,
            projectRAG: nil,
            git: nil
        )
        await model.loadIfNeeded()
        #expect(model.details.first { $0.id == "conversation-count" }?.value.contains("1") == true)

        // 新建 B 后作废缓存：非强制加载也必须看到新会话。
        let b = try conversations.createConversation(title: "B", projectPath: root.path, providerID: nil, modelName: nil)
        model.invalidateConversationData()
        await model.loadIfNeeded()

        var detail = try #require(model.details.first { $0.id == "conversation-count" })
        #expect(detail.value.contains("2"), "新建会话后卡片仍显示旧数量")
        var row = try #require(model.rows.first { $0.id == "last-conversation" })
        #expect(row.action == .resumeConversation(b), "新建会话后卡片仍指向旧会话")

        // 删除 A：指向已删除会话的「Last time here」行必须消失。
        conversations.deleteConversation(id: a)
        model.invalidateConversationData()
        await model.loadIfNeeded()

        detail = try #require(model.details.first { $0.id == "conversation-count" })
        #expect(detail.value.contains("1"))
        row = try #require(model.rows.first { $0.id == "last-conversation" })
        #expect(row.action == .resumeConversation(b))
        #expect(row.action != .resumeConversation(a))
    }

    /// 未作废时（旧行为）同项目非强制加载短路返回旧数据——锁住回归前提。
    @Test("未作废缓存时同项目非强制加载保持旧数据")
    func nonForcedLoadShortCircuitsWithoutInvalidation() async throws {
        let root = try makeProject(files: ["Package.swift"])
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = DefaultProjectProvider()
        try await provider.openProject(at: root.path, reason: .userSelected)

        let conversations = DefaultConversationManager()
        _ = try conversations.createConversation(title: "A", projectPath: root.path, providerID: nil, modelName: nil)

        let model = ProjectContextViewModel(
            project: provider,
            conversations: conversations,
            projectRAG: nil,
            git: nil
        )
        await model.loadIfNeeded()

        // 没有插件作废缓存（旧实现里 CRUD 静默发生）：非强制加载不重读。
        _ = try conversations.createConversation(title: "B", projectPath: root.path, providerID: nil, modelName: nil)
        await model.loadIfNeeded()

        let detail = try #require(model.details.first { $0.id == "conversation-count" })
        #expect(detail.value.contains("1"), "短路行为是旧行为的前提，改动时必须同步修插件观察者")
    }

    // MARK: - #889 关闭项目后在途加载不得写回

    /// 关闭项目后，在途的旧加载不得把旧项目的身份写回来。
    ///
    /// #889：`loadGeneration` 只在**真正开始加载**时递增，而「当前项目变为 nil」
    /// 的清空路径直接 `clear()` 返回，没有推进代次。于是项目 P 的加载若卡在
    /// 目录读取 / 索引状态 / Git 查询上，P 被关闭并清空后，旧加载返回时
    /// `generation == loadGeneration` 仍然成立，把 P 的 `identity`、`rows`、
    /// `details` 和 `loadedProjectPath` 全部写回。
    ///
    /// 界面后果：空消息页重新显示已经关闭的 P 的路径/身份，而且没有新项目
    /// 触发另一次加载时，这份错误状态不会被纠正。
    @Test("关闭项目后在途的旧加载不得写回旧项目身份")
    func closingProjectInvalidatesInFlightLoad() async throws {
        let root = try makeProject(files: ["Package.swift"])
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = DefaultProjectProvider()
        try await provider.openProject(at: root.path, reason: .userSelected)

        let rag = GatedRAGProvider()
        rag.status = ProjectRAGIndexStatus(
            projectPath: root.path,
            lastIndexedAt: Date().addingTimeInterval(-180),
            fileCount: 1_204,
            chunkCount: 3_000,
            isStale: false
        )
        rag.gate()

        let model = ProjectContextViewModel(project: provider, conversations: nil, projectRAG: rag, git: nil)

        // 第一步：让项目 P 的加载进入在途状态（卡在索引状态查询上）。
        let load = Task { @MainActor in
            await model.loadIfNeeded(force: true)
        }
        // 等加载真正进入挂起的 `indexStatus`。
        while rag.indexStatusCallCount == 0 {
            await Task.yield()
        }

        // 第二步：关闭项目 P —— 生产链路里这会触发一次清空加载。
        await provider.closeProject(reason: .userSelected)
        await model.loadIfNeeded(force: true)

        // 清空此刻是生效的。
        #expect(model.identity == nil)
        #expect(model.rows.isEmpty)

        // 第三步：让旧查询返回。旧加载必须被作废，不得写回 P 的身份。
        rag.release()
        await load.value

        #expect(
            model.identity == nil,
            "项目已关闭，旧加载却把已关闭项目的身份写了回来"
        )
        #expect(model.rows.isEmpty, "旧加载把已关闭项目的状态行写了回来")
        #expect(model.details.isEmpty, "旧加载把已关闭项目的详情写了回来")
        #expect(model.hasProject == false)
    }

    /// 清空必须让在途加载失效，而不只是把当前值清掉。
    ///
    /// 这条锁住 #889 的根因本身：清空路径必须推进 `loadGeneration`。
    @Test("关闭项目后清空不得留下残留身份")
    func clearingAfterCloseLeavesNoStaleIdentity() async throws {
        let root = try makeProject(files: ["Package.swift"])
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = DefaultProjectProvider()
        try await provider.openProject(at: root.path, reason: .userSelected)

        let model = ProjectContextViewModel(project: provider, conversations: nil, projectRAG: nil, git: nil)
        await model.loadIfNeeded()
        #expect(model.identity != nil)

        // 关闭项目 → 清空。
        await provider.closeProject(reason: .userSelected)
        await model.loadIfNeeded(force: true)

        #expect(model.identity == nil)
        #expect(model.hasProject == false)
    }

    /// 可展示身份必须同时满足「有项目」与「身份存在」。
    ///
    /// `identity` 是上一次加载留下的缓存，`hasProject` 反映当前是否真的有
    /// 项目选中——两者是独立条件。界面只认 `displayIdentity`，因此残留的
    /// 旧身份不会被展示出来。
    @Test("没有项目时不得展示残留的项目身份")
    func displayIdentityRequiresCurrentProject() async throws {
        let root = try makeProject(files: ["Package.swift"])
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = DefaultProjectProvider()
        try await provider.openProject(at: root.path, reason: .userSelected)

        let model = ProjectContextViewModel(project: provider, conversations: nil, projectRAG: nil, git: nil)
        await model.loadIfNeeded()

        // 有项目且身份已加载 → 可展示。
        #expect(model.hasProject)
        #expect(model.displayIdentity != nil)

        // 项目关闭后，即使身份还残留（这里由清空路径保证为 nil，
        // 但判定必须独立于 identity 是否为 nil），也不可展示。
        await provider.closeProject(reason: .userSelected)
        #expect(model.hasProject == false)
        #expect(model.displayIdentity == nil)
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

    /// 回归 #314：项目维度按 (path, startOfDay) 缓存会话集合，同一天新建的会话
    /// 不会改变缓存键；强制刷新必须绕过该缓存重新取集合，否则新会话的消息漏统计。
    @Test("强制刷新重新取项目会话集合，当天新建会话也计入")
    func forcedReloadRefreshesProjectConversationIDs() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-scope-force-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = DefaultProjectProvider()
        try await provider.openProject(at: root.path, reason: .userSelected)

        let conversations = DefaultConversationManager()
        let a = try conversations.createConversation(title: "A", projectPath: root.path, providerID: nil, modelName: nil)

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
        #expect(manager.queriedConversationIDs.last == [a.uuidString])

        // 同一天新建会话 B：缓存键 (path, day) 不变。
        let b = try conversations.createConversation(title: "B", projectPath: root.path, providerID: nil, modelName: nil)

        // 切到 All 再切回 This project，触发 force=true 的重新加载。
        await model.setScope(.all)
        await model.setScope(.project)

        let queried = try #require(manager.queriedConversationIDs.last ?? nil)
        #expect(queried.contains(a.uuidString))
        #expect(queried.contains(b.uuidString), "强制刷新必须计入当天新建的会话 B")
    }

    @Test("file tree navigation restores Chat before selecting Explorer")
    func fileTreeNavigationActivatesChatFirst() {
        let recorder = NavigationRecorder()
        let activityBar = RecordingActivityBar(recorder: recorder)
        activityBar.items = [ActivityBarItem(
            id: "com.coffic.lumi.plugin.chat-panel.entry",
            title: "Chat",
            systemImage: "bubble.left",
            ownerPluginID: "com.coffic.lumi.plugin.chat-panel"
        )]
        let rail = RecordingRail(recorder: recorder)
        rail.tabs = [RailTabItem(
            id: "explorer",
            category: .fileTree,
            title: "Explorer",
            systemImage: "folder"
        ) { EmptyView() }]
        let services = MessageListEmptyServices(
            project: nil,
            promptSuggestions: nil,
            promptSuggestionExecutor: nil,
            messages: nil,
            conversations: nil,
            projectRAG: nil,
            git: nil,
            activityBar: activityBar,
            railView: rail
        )

        ProjectContextNavigator.openFileTree(services: services)

        // Browser 等工作区隐藏了 Rail；必须先切 Chat 让 Rail 重新挂载，
        // 再选中文件树，否则这次点击没有任何可见结果。
        #expect(recorder.events == [
            "activity:com.coffic.lumi.plugin.chat-panel.entry",
            "tab:explorer",
        ])
    }

    @Test("file tree navigation still selects the tab without an activity bar")
    func fileTreeNavigationFallsBackToRail() {
        let recorder = NavigationRecorder()
        let rail = RecordingRail(recorder: recorder)
        rail.tabs = [RailTabItem(
            id: "explorer",
            category: .fileTree,
            title: "Explorer",
            systemImage: "folder"
        ) { EmptyView() }]
        let services = MessageListEmptyServices(
            project: nil,
            promptSuggestions: nil,
            promptSuggestionExecutor: nil,
            messages: nil,
            conversations: nil,
            projectRAG: nil,
            git: nil,
            activityBar: nil,
            railView: rail
        )

        ProjectContextNavigator.openFileTree(services: services)

        #expect(recorder.events == ["tab:explorer"])
    }

    @Test("git navigation activates an already registered workspace entry")
    func gitNavigationActivatesExistingEntry() async {
        let recorder = NavigationRecorder()
        let activityBar = RecordingActivityBar(recorder: recorder)
        activityBar.items = [Self.gitWorkspaceItem]
        let services = MessageListEmptyServices(
            project: nil,
            promptSuggestions: nil,
            promptSuggestionExecutor: nil,
            messages: nil,
            conversations: nil,
            projectRAG: nil,
            git: nil,
            activityBar: activityBar,
            railView: nil
        )

        await ProjectContextNavigator.openGitWorkspace(services: services)

        #expect(recorder.events == ["activity:\(ProjectContextNavigator.gitWorkspacePluginID).entry"])
    }

    @Test("git navigation enables the workspace when its entry is missing")
    func gitNavigationEnablesDisabledWorkspace() async {
        let recorder = NavigationRecorder()
        let activityBar = RecordingActivityBar(recorder: recorder)
        let control = RecordingPluginControl(recorder: recorder, activityBar: activityBar)
        let services = MessageListEmptyServices(
            project: nil,
            promptSuggestions: nil,
            promptSuggestionExecutor: nil,
            messages: nil,
            conversations: nil,
            projectRAG: nil,
            git: nil,
            activityBar: activityBar,
            pluginControl: control,
            railView: nil
        )

        await ProjectContextNavigator.openGitWorkspace(services: services)

        // 先启用插件，等它注册入口后再激活；否则目标 id 从未存在，
        // 点击表现就是「什么都不发生」。
        #expect(control.enabledIDs == [ProjectContextNavigator.gitWorkspacePluginID])
        #expect(recorder.events == [
            "enable:\(ProjectContextNavigator.gitWorkspacePluginID)",
            "activity:\(ProjectContextNavigator.gitWorkspacePluginID).entry",
        ])
    }

    @Test("git navigation leaves the UI untouched when enabling fails")
    func gitNavigationStopsWhenEnablingFails() async {
        let recorder = NavigationRecorder()
        let activityBar = RecordingActivityBar(recorder: recorder)
        let control = RecordingPluginControl(recorder: recorder, activityBar: activityBar, succeeds: false)
        let services = MessageListEmptyServices(
            project: nil,
            promptSuggestions: nil,
            promptSuggestionExecutor: nil,
            messages: nil,
            conversations: nil,
            projectRAG: nil,
            git: nil,
            activityBar: activityBar,
            pluginControl: control,
            railView: nil
        )

        await ProjectContextNavigator.openGitWorkspace(services: services)

        #expect(recorder.events == ["enable:\(ProjectContextNavigator.gitWorkspacePluginID)"])
    }

    @Test("the git row only offers an action when the workspace can be reached")
    func gitRowAvailabilityFollowsEntryAndController() {
        let recorder = NavigationRecorder()
        let activityBar = RecordingActivityBar(recorder: recorder)

        let unreachable = MessageListEmptyServices(
            project: nil,
            promptSuggestions: nil,
            promptSuggestionExecutor: nil,
            messages: nil,
            conversations: nil,
            projectRAG: nil,
            git: nil,
            activityBar: activityBar,
            railView: nil
        )
        #expect(!ProjectContextNavigator.canOpenGitWorkspace(services: unreachable))

        let enabledLater = MessageListEmptyServices(
            project: nil,
            promptSuggestions: nil,
            promptSuggestionExecutor: nil,
            messages: nil,
            conversations: nil,
            projectRAG: nil,
            git: nil,
            activityBar: activityBar,
            pluginControl: RecordingPluginControl(recorder: recorder),
            railView: nil
        )
        #expect(ProjectContextNavigator.canOpenGitWorkspace(services: enabledLater))

        activityBar.items = [Self.gitWorkspaceItem]
        #expect(ProjectContextNavigator.canOpenGitWorkspace(services: unreachable))
    }

    private static var gitWorkspaceItem: ActivityBarItem {
        ActivityBarItem(
            id: "\(ProjectContextNavigator.gitWorkspacePluginID).entry",
            title: "Git",
            systemImage: "arrow.triangle.branch",
            ownerPluginID: ProjectContextNavigator.gitWorkspacePluginID
        )
    }
}
