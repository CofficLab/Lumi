import Foundation
import ProviderConversation
import ProviderProject
import Testing
@testable import PluginConversationList

@Test @MainActor func initialLoadAndHeaderReflectConversationAndProjectState() async throws {
    let conversations = DefaultConversationManager()
    let project = DefaultProjectProvider()
    try await project.openProject(at: "/workspace/One")
    _ = try conversations.createConversation(title: "One", projectPath: "/workspace/One", providerID: nil, modelName: nil)
    try await project.openProject(at: "/workspace/Two")
    _ = try conversations.createConversation(title: "Two", projectPath: "/workspace/Two", providerID: nil, modelName: nil)

    let context = makeListContext(conversations: conversations, project: project)
    let viewModel = ConversationListViewModel(
        context: context,
        attentionStore: ConversationAttentionStore(),
        sortStabilizer: ConversationSortStabilizer(),
        scope: .all
    )
    #expect(viewModel.isLoading)
    #expect(viewModel.headerVisible == false)
    #expect(viewModel.headerTitle == "所有项目的对话")

    await viewModel.loadInitialIfNeeded()
    await viewModel.loadInitialIfNeeded()

    #expect(!viewModel.isLoading)
    #expect(viewModel.conversations.count == 2)
    #expect(viewModel.hasMultipleProjects)
    #expect(viewModel.headerVisible)
    #expect(viewModel.selectedConversationID == conversations.selectedConversationID)
}

@Test @MainActor func currentProjectScopeFiltersReloadAndUpdatesProjectTitle() async throws {
    let conversations = DefaultConversationManager()
    let project = DefaultProjectProvider()
    try await project.openProject(at: "/workspace/One")
    _ = try conversations.createConversation(title: "One", projectPath: "/workspace/One", providerID: nil, modelName: nil)
    try await project.openProject(at: "/workspace/Two")
    let selectedID = try conversations.createConversation(title: "Two", projectPath: "/workspace/Two", providerID: nil, modelName: nil)
    let viewModel = ConversationListViewModel(
        context: makeListContext(conversations: conversations, project: project),
        attentionStore: ConversationAttentionStore(),
        sortStabilizer: ConversationSortStabilizer(),
        scope: .currentProject
    )

    await viewModel.loadInitialIfNeeded()

    #expect(viewModel.conversations.map(\.id) == [selectedID])
    #expect(viewModel.resolvedProjectPath == "/workspace/Two")
    #expect(viewModel.headerVisible)
    #expect(viewModel.headerTitle == "项目对话 (Two)")
    #expect(!viewModel.hasMultipleProjects)
    // 徽标条数只统计当前项目的对话，不含其它项目的。
    #expect(viewModel.conversationCount == 1)
}

@Test @MainActor func conversationCountReflectsScopeAndUpdatesOnChange() async throws {
    let conversations = DefaultConversationManager()
    let project = DefaultProjectProvider()
    try await project.openProject(at: "/workspace/One")
    _ = try conversations.createConversation(title: "One", projectPath: "/workspace/One", providerID: nil, modelName: nil)
    try await project.openProject(at: "/workspace/Two")
    _ = try conversations.createConversation(title: "Two", projectPath: "/workspace/Two", providerID: nil, modelName: nil)

    let context = makeListContext(conversations: conversations, project: project)
    // 观察器把「对话增删」转成上下文事件，ViewModel 收到后自动刷新条数。
    let contextObserver = ConversationListContextObserver(
        conversations: conversations,
        conversationState: nil,
        context: context
    )

    let allViewModel = ConversationListViewModel(
        context: context,
        attentionStore: ConversationAttentionStore(),
        sortStabilizer: ConversationSortStabilizer(),
        scope: .all
    )
    await allViewModel.loadInitialIfNeeded()
    // 「所有项目」统计全库顶层对话。
    #expect(allViewModel.conversationCount == 2)

    let currentViewModel = ConversationListViewModel(
        context: context,
        attentionStore: ConversationAttentionStore(),
        sortStabilizer: ConversationSortStabilizer(),
        scope: .currentProject
    )
    await currentViewModel.loadInitialIfNeeded()
    // 「当前项目」只统计当前项目下的对话。
    #expect(currentViewModel.conversationCount == 1)

    // 新建对话后条数随之更新。
    _ = try conversations.createConversation(title: "Three", projectPath: "/workspace/Two", providerID: nil, modelName: nil)
    let didUpdate = await waitUntil {
        currentViewModel.conversationCount == 2
    }
    #expect(didUpdate)

    currentViewModel.cancel()
    allViewModel.cancel()
    contextObserver.cancel()
}

@Test @MainActor func nextPageAppendsOnlyTheRemainingConversations() async throws {
    let conversations = DefaultConversationManager()
    var expectedIDs: Set<UUID> = []
    for index in 0..<41 {
        expectedIDs.insert(try conversations.createConversation(
            title: "Conversation \(index)",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        ))
    }
    let viewModel = ConversationListViewModel(
        context: makeListContext(conversations: conversations),
        attentionStore: ConversationAttentionStore(),
        sortStabilizer: ConversationSortStabilizer(),
        scope: .all
    )

    await viewModel.reload()
    #expect(viewModel.conversations.count == 40)
    #expect(viewModel.hasMore)

    await viewModel.loadNextPage()
    #expect(viewModel.conversations.count == 41)
    #expect(Set(viewModel.conversations.map(\.id)) == expectedIDs)
    #expect(!viewModel.hasMore)

    await viewModel.loadNextPage()
    #expect(viewModel.conversations.count == 41)
}

@Test @MainActor func selectionClearsAttentionAndDeleteUsesConversationProvider() async throws {
    let conversations = DefaultConversationManager()
    let firstID = try conversations.createConversation(title: "First", projectPath: nil, providerID: nil, modelName: nil)
    let selectedID = try conversations.createConversation(title: "Selected", projectPath: nil, providerID: nil, modelName: nil)
    let context = makeListContext(conversations: conversations)
    let contextObserver = ConversationListContextObserver(
        conversations: conversations,
        conversationState: nil,
        context: context
    )
    let attentionStore = ConversationAttentionStore()
    let viewModel = ConversationListViewModel(
        context: context,
        attentionStore: attentionStore,
        sortStabilizer: ConversationSortStabilizer(),
        scope: .all
    )
    attentionStore.markNeedsAttention(conversationID: firstID)
    attentionStore.markNeedsAttention(conversationID: selectedID)
    #expect(viewModel.needsAttention(for: firstID))
    #expect(viewModel.needsAttention(for: selectedID))
    #expect(viewModel.conversationState(for: selectedID) == nil)

    viewModel.selectConversation(id: firstID)
    #expect(viewModel.immediateSelectionID == firstID)
    let didSelect = await waitUntil {
        viewModel.selectedConversationID == firstID && !viewModel.needsAttention(for: firstID)
    }
    #expect(didSelect)
    #expect(!viewModel.needsAttention(for: firstID))
    #expect(viewModel.needsAttention(for: selectedID))

    viewModel.deleteConversation(id: firstID)
    #expect(await conversations.conversationCount(projectPath: nil) == 1)
    viewModel.cancel()
    contextObserver.cancel()
}

@Test @MainActor func automationLevelChangeUpdatesOnlyTheAffectedConversationRow() async throws {
    let conversations = DefaultConversationManager()
    let firstID = try conversations.createConversation(title: "First", projectPath: nil, providerID: nil, modelName: nil)
    let secondID = try conversations.createConversation(title: "Second", projectPath: nil, providerID: nil, modelName: nil)
    let context = makeListContext(conversations: conversations)
    let contextObserver = ConversationListContextObserver(
        conversations: conversations,
        conversationState: nil,
        context: context
    )
    let viewModel = ConversationListViewModel(
        context: context,
        attentionStore: ConversationAttentionStore(),
        sortStabilizer: ConversationSortStabilizer(),
        scope: .all
    )
    await viewModel.reload()

    // - Important: 「未受影响」的基准必须是**创建时的实际值**，不能假定为 nil。
    //   `createConversation` 会把 `globalAutomationLevel`（默认 `.build`）
    //   写入每个新会话，因此 `automationLevel` 实际恒非 nil。曾经这里断言
    //   `== nil`，于是该用例长期失败 —— 但失败的不是产品，而是断言基准错了：
    //   它把「默认值」误当成了「缺省值」。
    let untouchedBaseline = viewModel.conversations
        .first(where: { $0.id == secondID })?.automationLevel
    #expect(
        untouchedBaseline == .build,
        "新会话应继承全局自动化等级 .build，实际 \(String(describing: untouchedBaseline))"
    )

    conversations.setAutomationLevel(.autonomous, for: firstID)

    #expect(viewModel.conversations.first(where: { $0.id == firstID })?.automationLevel == .autonomous)
    // 未被修改的会话必须**保持原值**，而不是变成 nil 或跟着变。
    #expect(
        viewModel.conversations.first(where: { $0.id == secondID })?.automationLevel == untouchedBaseline,
        "第二个会话不应被这次修改影响"
    )
    viewModel.cancel()
    contextObserver.cancel()
}

/// 旧项目的 reload 结果不能写进切换后的项目列表。
@Test @MainActor func reloadDiscardsSnapshotFromPreviousProject() async throws {
    let project = DefaultProjectProvider()
    try await project.openProject(at: "/workspace/One")

    let oldA = ConversationSummary(
        id: UUID(), title: "A", createdAt: Date(), updatedAt: Date(), projectPath: "/workspace/One"
    )
    let newB = ConversationSummary(
        id: UUID(), title: "B", createdAt: Date(), updatedAt: Date(), projectPath: "/workspace/Two"
    )
    let conversations = DelayedConversationManager(summaries: [oldA, newB])
    conversations.setDelay(.milliseconds(400), forProjectPath: "/workspace/One")

    let viewModel = ConversationListViewModel(
        context: makeListContext(conversations: conversations, project: project),
        attentionStore: ConversationAttentionStore(),
        sortStabilizer: ConversationSortStabilizer(),
        scope: .currentProject
    )

    let stale = Task { await viewModel.reload() }
    try await Task.sleep(for: .milliseconds(50))
    try await project.openProject(at: "/workspace/Two")
    await viewModel.reload()
    await stale.value

    #expect(
        !viewModel.conversations.contains { $0.id == oldA.id },
        "旧项目的快照不能写进新项目列表"
    )
    #expect(await waitUntil { viewModel.conversations.map(\.id) == [newB.id] })
}

/// 翻页结果晚到时，列表已被切项目刷新替换，不能把旧页追加到新列表。
@Test @MainActor func loadNextPageDoesNotAppendStalePageAfterProjectSwitch() async throws {
    let project = DefaultProjectProvider()
    try await project.openProject(at: "/workspace/One")

    let base = Date()
    let many = (0..<60).map { index in
        ConversationSummary(
            id: UUID(),
            title: "C\(index)",
            createdAt: base,
            updatedAt: base.addingTimeInterval(-Double(index) * 60),
            projectPath: "/workspace/One"
        )
    }
    let other = ConversationSummary(
        id: UUID(), title: "Other", createdAt: base, updatedAt: base, projectPath: "/workspace/Two"
    )
    let conversations = DelayedConversationManager(summaries: many + [other])

    let viewModel = ConversationListViewModel(
        context: makeListContext(conversations: conversations, project: project),
        attentionStore: ConversationAttentionStore(),
        sortStabilizer: ConversationSortStabilizer(),
        scope: .currentProject
    )
    await viewModel.reload()
    #expect(await waitUntil { viewModel.conversations.count == 40 })
    #expect(viewModel.hasMore)

    conversations.setDelay(.milliseconds(400), forProjectPath: "/workspace/One")
    let more = Task { await viewModel.loadNextPage() }
    try await Task.sleep(for: .milliseconds(50))
    try await project.openProject(at: "/workspace/Two")
    await viewModel.reload()

    await more.value
    #expect(await waitUntil { viewModel.conversations.map(\.id) == [other.id] })
}

@MainActor
private func makeListContext(
    conversations: any ConversationManaging,
    project: (any ProjectProviding)? = nil
) -> ConversationListContext {
    ConversationListContext(
        conversations: conversations,
        project: project,
        agentTurn: nil,
        conversationState: nil,
        chat: nil
    )
}

@MainActor
private func waitUntil(
    timeout: Duration = .seconds(1),
    condition: @MainActor () -> Bool
) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while clock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return condition()
}

/// 只为分页测试提供「按项目路径注入延迟」的会话管理器；
/// 其余成员走 `ConversationManaging` 的默认实现。
@MainActor
private final class DelayedConversationManager: ConversationManaging {
    private var summaries: [ConversationSummary]
    private var delays: [String: Duration] = [:]

    init(summaries: [ConversationSummary]) {
        self.summaries = summaries
    }

    func setDelay(_ delay: Duration?, forProjectPath path: String) {
        delays[path] = delay
    }

    var conversations: [ConversationSummary] { summaries }
    var selectedConversationID: UUID? { nil }
    var currentTitle: String { "" }
    var dataDirectory: URL { URL(fileURLWithPath: "/tmp/PluginConversationListTests") }

    func selectConversation(id: UUID) {}
    func deselectConversation() {}
    func deleteConversation(id: UUID) {}

    func createConversation(
        title: String?,
        projectPath: String?,
        providerID: String?,
        modelName: String?
    ) throws -> UUID {
        try createConversation(
            title: title,
            projectPath: projectPath,
            providerID: providerID,
            modelName: modelName,
            parentConversationID: nil
        )
    }

    func createConversation(
        title: String?,
        projectPath: String?,
        providerID: String?,
        modelName: String?,
        parentConversationID: UUID?
    ) throws -> UUID {
        let id = UUID()
        summaries.append(ConversationSummary(
            id: id, title: title ?? "New", createdAt: Date(), updatedAt: Date(), projectPath: projectPath
        ))
        return id
    }

    func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool { false }
    func markConversationActive(id: UUID, messageDate: Date) {}
    func isSending(for conversationID: UUID?) -> Bool { false }
    func providerID(for conversationID: UUID?) -> String? { nil }
    func modelName(for conversationID: UUID?) -> String? { nil }
    func selectProvider(id: String, model: String?, for conversationID: UUID?) {}

    var globalVerbosity: ResponseVerbosity { .standard }
    func verbosity(for conversationID: UUID?) -> ResponseVerbosity { globalVerbosity }
    func setVerbosity(_ level: ResponseVerbosity, for conversationID: UUID?) {}
    func setGlobalVerbosity(_ level: ResponseVerbosity) {}

    var globalReasoningEffort: ReasoningEffort? { nil }
    func reasoningEffort(for conversationID: UUID?) -> ReasoningEffort { .medium }
    func reasoningEffortOptional(for conversationID: UUID?) -> ReasoningEffort? { nil }
    func setReasoningEffort(_ effort: ReasoningEffort, for conversationID: UUID?) {}
    func clearReasoningEffort(for conversationID: UUID?) {}
    func setGlobalReasoningEffort(_ effort: ReasoningEffort?) {}

    var globalAutomationLevel: AutomationLevel { .chat }
    func automationLevel(for conversationID: UUID?) -> AutomationLevel { globalAutomationLevel }
    func setAutomationLevel(_ level: AutomationLevel, for conversationID: UUID?) {}
    func setGlobalAutomationLevel(_ level: AutomationLevel) {}

    var globalLanguage: ConversationLanguage { .chinese }
    func language(for conversationID: UUID?) -> ConversationLanguage { globalLanguage }
    func setLanguage(_ language: ConversationLanguage, for conversationID: UUID?) {}
    func setGlobalLanguage(_ language: ConversationLanguage) {}

    func addSelectedConversationObserver(
        _ observer: @escaping (UUID?) -> Void
    ) -> any SelectedConversationObserverHandle {
        NoopObserverHandle()
    }

    func conversationProjectCount() async -> Int {
        Set(summaries.compactMap(\.projectPath)).count
    }

    func conversationCount(projectPath: String?) async -> Int {
        guard let projectPath else { return summaries.count }
        return summaries.filter { $0.projectPath == projectPath }.count
    }

    func fetchConversationPage(
        limit: Int,
        beforeUpdatedAt: Date?,
        beforeID: UUID?
    ) async -> [ConversationSummary] {
        page(summaries, limit: limit, beforeUpdatedAt: beforeUpdatedAt, beforeID: beforeID)
    }

    func fetchConversationPage(
        limit: Int,
        beforeUpdatedAt: Date?,
        beforeID: UUID?,
        includingChildConversations: Bool,
        projectPath: String
    ) async -> [ConversationSummary] {
        if let delay = delays[projectPath] {
            try? await Task.sleep(for: delay)
        }
        return page(
            summaries.filter { $0.projectPath == projectPath },
            limit: limit,
            beforeUpdatedAt: beforeUpdatedAt,
            beforeID: beforeID
        )
    }

    private func page(
        _ items: [ConversationSummary],
        limit: Int,
        beforeUpdatedAt: Date?,
        beforeID: UUID?
    ) -> [ConversationSummary] {
        var list = items.sorted { $0.updatedAt > $1.updatedAt }
        if let beforeID, let index = list.firstIndex(where: { $0.id == beforeID }) {
            list = Array(list.dropFirst(index + 1))
        } else if let beforeUpdatedAt {
            list = list.filter { $0.updatedAt < beforeUpdatedAt }
        }
        return Array(list.prefix(limit))
    }
}

private final class NoopObserverHandle: SelectedConversationObserverHandle {
    func cancel() {}
}
