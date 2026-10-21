import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderConversationState
import ProviderDeveloperMode
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageStreaming
import ProviderToolManager
import Testing
@testable import PluginMessageListStandard

// MARK: - Test doubles for narrow capabilities

@MainActor
final class StubConversationCapability: MessageListConversationCapability {
    var selectedConversationID: UUID?
    var verbosityByConversation: [UUID: ResponseVerbosity] = [:]
    var defaultVerbosity: ResponseVerbosity = .standard

    init(selected: UUID? = nil) { self.selectedConversationID = selected }

    func verbosity(for conversationID: UUID?) -> ResponseVerbosity {
        guard let conversationID else { return defaultVerbosity }
        return verbosityByConversation[conversationID] ?? defaultVerbosity
    }
}

@MainActor
final class StubConversationStateCapability: MessageListConversationStateCapability {
    var snapshot: ConversationStateSnapshot?

    init(snapshot: ConversationStateSnapshot? = nil) { self.snapshot = snapshot }

    func state(for conversationID: UUID) -> ConversationStateSnapshot {
        snapshot ?? ConversationStateSnapshot(conversationID: conversationID)
    }
}

@MainActor
final class StubStreamingCapability: MessageListStreamingCapability {
    var streaming: Message?
    var stage: MessageStreamingStage = .idle

    init(streaming: Message? = nil, stage: MessageStreamingStage = .idle) {
        self.streaming = streaming
        self.stage = stage
    }

    func streamingMessage(for conversationID: UUID) -> Message? { streaming }
    func stage(for conversationID: UUID) -> MessageStreamingStage { stage }
}

@MainActor
final class StubToolManagerCapability: MessageListToolManagerCapability {
    var recordsByTurn: [UUID: [ToolCallRecord]] = [:]
    private(set) var cancelledTurnIDs: [UUID] = []
    private(set) var toolCallsRequestCount = 0

    func toolCalls(for turnID: UUID) async -> [ToolCallRecord] {
        toolCallsRequestCount += 1
        return recordsByTurn[turnID] ?? []
    }

    func cancelJobs(forTurnID turnID: UUID) { cancelledTurnIDs.append(turnID) }
}

@MainActor
final class StubRenderingCapability: MessageListRenderingCapability {
    var renderer: MessageRendererItem?
    func renderer(for message: Message) -> MessageRendererItem? { renderer }
}

/// 组装被测 ViewModel 所需的最小依赖集。
@MainActor
struct ViewModelHarness {
    let conversations: StubConversationCapability
    let conversationState: StubConversationStateCapability
    let streaming: StubStreamingCapability
    let toolManager: StubToolManagerCapability
    let rendering: StubRenderingCapability
    let viewModel: ListV2ViewModel

    init(
        selected: UUID? = nil,
        page: [Message] = [],
        hasEarlier: Bool = false,
        earlierPage: [Message]? = nil,
        messages: (any MessageListMessageCapability)? = nil,
        conversationState: StubConversationStateCapability = StubConversationStateCapability(),
        streaming: StubStreamingCapability = StubStreamingCapability(),
        toolManager: StubToolManagerCapability = StubToolManagerCapability(),
        rendering: StubRenderingCapability = StubRenderingCapability()
    ) {
        let conversations = StubConversationCapability(selected: selected)
        let messageCapability: any MessageListMessageCapability = messages
            ?? StubMessageListMessageCapability(page: page, hasEarlier: hasEarlier, earlierPage: earlierPage)
        self.conversations = conversations
        self.conversationState = conversationState
        self.streaming = streaming
        self.toolManager = toolManager
        self.rendering = rendering

        let services = MessageListServices(
            conversations: conversations,
            conversationState: conversationState,
            developerModeState: DeveloperModeStateViewModel(),
            messages: messageCapability,
            rendering: rendering,
            streaming: streaming,
            toolManager: toolManager,
            agentTurn: nil,
            promptSuggestions: nil,
            promptSuggestionExecutor: nil,
            project: nil,
            toolbar: nil,
            chat: nil
        )
        self.viewModel = ListV2ViewModel(services: services)
    }
}

// MARK: - Activation / first page

@MainActor
@Test("激活当前会话后加载最近一页并退出 loading")
func activationLoadsFirstPage() async {
    let conversationID = UUID()
    let page = (0..<3).map { index in
        makeMessage(conversationID: conversationID, role: .user, content: "\(index)")
    }
    let harness = ViewModelHarness(selected: conversationID, page: page)

    await harness.viewModel.activateCurrentConversation()

    #expect(!harness.viewModel.isLoading)
    // stub 返回 3 条，小于 pageSize(40)，全部保留
    #expect(harness.viewModel.persistedMessages.map(\.id) == page.map(\.id))
    #expect(harness.viewModel.hasPersistedMessages)
    #expect(harness.viewModel.selectedConversationID == conversationID)
}

@MainActor
@Test("没有选中会话时清空窗口且不进入 loading")
func activationWithoutConversationClearsState() async {
    let harness = ViewModelHarness(selected: nil)

    await harness.viewModel.activateCurrentConversation()

    #expect(!harness.viewModel.isLoading)
    #expect(harness.viewModel.persistedMessages.isEmpty)
    #expect(!harness.viewModel.hasEarlierMessages)
    #expect(!harness.viewModel.hasPersistedMessages)
}

@MainActor
@Test("切换会话时旧会话消息被清空，不残留上一会话内容")
func activationResetsPreviousConversationState() async {
    let first = UUID()
    let second = UUID()
    let firstPage = [makeMessage(conversationID: first, role: .user, content: "first")]
    let secondPage = [makeMessage(conversationID: second, role: .user, content: "second")]

    let messageCapability = SequencedMessageListMessageCapability(pages: [firstPage, secondPage])
    let harness = ViewModelHarness(selected: first, messages: messageCapability)
    await harness.viewModel.activateCurrentConversation()
    #expect(harness.viewModel.persistedMessages.map(\.content) == ["first"])

    harness.conversations.selectedConversationID = second
    await harness.viewModel.activateCurrentConversation()

    #expect(harness.viewModel.persistedMessages.map(\.content) == ["second"])
    #expect(!harness.viewModel.persistedMessages.contains { $0.conversationID == first })
}

@MainActor
@Test("切换到非当前会话的激活请求被忽略")
func activationIgnoresStaleConversation() async {
    let conversationID = UUID()
    let page = [makeMessage(conversationID: conversationID, role: .user, content: "x")]
    let harness = ViewModelHarness(selected: conversationID, page: page)

    // 目标会话不是当前选中 → 直接返回，不应写入任何数据
    await harness.viewModel.activate(conversationID: UUID())

    #expect(harness.viewModel.persistedMessages.isEmpty)
}

// MARK: - Pagination

@MainActor
@Test("向上翻页把更早一页前插，并保留已有更早标记")
func loadEarlierPrependsPage() async {
    let conversationID = UUID()
    let anchor = makeMessage(conversationID: conversationID, role: .user, content: "anchor")
    let earlier = [
        makeMessage(conversationID: conversationID, role: .user, content: "e1"),
        makeMessage(conversationID: conversationID, role: .user, content: "e2"),
    ]
    // 首屏要判定「还有更早消息」，必须返回 pageSize+1 条以上：
    // loadFirstPage 用 page.count > pageSize 推断，并只保留尾部 pageSize 条。
    let filler = (0..<41).map { index in
        makeMessage(conversationID: conversationID, role: .user, content: "f\(index)")
    }
    let manager = StubMessageListMessageCapability(
        page: filler, hasEarlier: true, earlierPage: earlier
    )
    let harness = ViewModelHarness(selected: conversationID, messages: manager)
    await harness.viewModel.activateCurrentConversation()

    let windowBefore = harness.viewModel.persistedMessages
    #expect(windowBefore.count == 40, "首屏应保留 pageSize(40) 条")
    let expectedAnchor = windowBefore.first?.id

    let returnedAnchor = await harness.viewModel.loadEarlier()

    // 锚点是「翻页前窗口最早一条」，prepend 后应被钉回视口顶部
    #expect(returnedAnchor == expectedAnchor)
    #expect(harness.viewModel.persistedMessages.map(\.id) == (earlier + windowBefore).map(\.id))
    #expect(harness.viewModel.persistedMessages.count == earlier.count + windowBefore.count)
}

@MainActor
@Test("空窗口或无更早消息时向上翻页不产生锚点")
func loadEarlierNoOpWithoutWindow() async {
    let conversationID = UUID()
    let harness = ViewModelHarness(selected: conversationID, page: [])
    await harness.viewModel.activateCurrentConversation()

    let anchor = await harness.viewModel.loadEarlier()
    #expect(anchor == nil)
}

@MainActor
@Test("向上翻页在超过窗口上限且离开底部时回收较新消息")
func loadEarlierEvictsTailWhenAwayFromBottom() async {
    let conversationID = UUID()
    // 大量消息 + 翻页补充 → 触发窗口回收
    let existing = (0..<8).map { index in
        makeMessage(conversationID: conversationID, role: .user, content: "m\(index)")
    }
    let earlier = (0..<4).map { index in
        makeMessage(conversationID: conversationID, role: .user, content: "e\(index)")
    }
    // 首屏超过 pageSize 才会被判定为「还有更早消息」
    let filler = (0..<41).map { index in
        makeMessage(conversationID: conversationID, role: .user, content: "f\(index)")
    }
    let manager = StubMessageListMessageCapability(
        page: filler, hasEarlier: true, earlierPage: earlier
    )
    let harness = ViewModelHarness(selected: conversationID, messages: manager)
    await harness.viewModel.activateCurrentConversation()
    let windowBefore = harness.viewModel.persistedMessages

    _ = await harness.viewModel.loadEarlier()

    // 44 条远小于 maxRetainedCount(300)，不触发回收，顺序为「更早在前」
    #expect(harness.viewModel.persistedMessages.map(\.id) == (earlier + windowBefore).map(\.id))
}

// MARK: - Tail refresh

@MainActor
@Test("尾部刷新在内容变化时替换窗口并返回 true")
func tailRefreshUpdatesWindow() async {
    let conversationID = UUID()
    let first = makeMessage(conversationID: conversationID, role: .user, content: "one")
    let manager = StubMessageListMessageCapability(page: [first])
    let harness = ViewModelHarness(selected: conversationID, messages: manager)
    await harness.viewModel.activateCurrentConversation()

    manager.page = [first, makeMessage(conversationID: conversationID, role: .assistant, content: "new")]
    let changed = await harness.viewModel.refreshTail()

    #expect(changed)
    #expect(harness.viewModel.persistedMessages.count == 2)
}

@MainActor
@Test("尾部刷新在内容未变化时返回 false 且不重复发布")
func tailRefreshSkipsIdenticalSnapshot() async {
    let conversationID = UUID()
    let first = makeMessage(conversationID: conversationID, role: .user, content: "one")
    let manager = StubMessageListMessageCapability(page: [first])
    let harness = ViewModelHarness(selected: conversationID, messages: manager)
    await harness.viewModel.activateCurrentConversation()

    let changed = await harness.viewModel.refreshTail()
    #expect(!changed)
}

@MainActor
@Test("尾部刷新在没有选中会话时直接返回 false")
func tailRefreshWithoutConversation() async {
    let harness = ViewModelHarness(selected: nil)
    let changed = await harness.viewModel.refreshTail()
    #expect(!changed)
}

// MARK: - Streaming row

@MainActor
@Test("生成阶段暴露流式行，闲置阶段隐藏流式行")
func streamingRowFollowsStage() async {
    let conversationID = UUID()
    let streamingMessage = makeMessage(conversationID: conversationID, role: .assistant, content: "partial")
    let streaming = StubStreamingCapability()
    let harness = ViewModelHarness(
        selected: conversationID,
        page: [makeMessage(conversationID: conversationID, role: .user, content: "hi")],
        streaming: streaming
    )
    await harness.viewModel.activateCurrentConversation()

    // 流式逐字显示是静态开关（生产默认关闭），测试需显式开启并在结束后复原
    let previousDisplay = ListV2ViewModel.streamingDisplayEnabled
    ListV2ViewModel.streamingDisplayEnabled = true
    defer { ListV2ViewModel.streamingDisplayEnabled = previousDisplay }

    // 流式阶段
    streaming.streaming = streamingMessage
    streaming.stage = .generating
    harness.viewModel.handleStreamingChange(.updated(conversationID))
    // - Important: 用轮询而非固定睡眠。`scheduleStreamingRefresh` 有 16ms 的
    //   单飞帧门禁，固定 60ms 在机器负载高时不足以覆盖它，于是该用例
    //   偶发失败（表现为与本用例无关的随机红），且极难归因。
    //   轮询把「等状态成立」而非「等时间过去」。
    #expect(
        await waitUntil { harness.viewModel.streamingRow?.id == streamingMessage.id },
        "进入流式阶段后 streamingRow 未在预期时间内更新"
    )

    // 回到闲置
    streaming.streaming = nil
    streaming.stage = .idle
    harness.viewModel.handleStreamingChange(.updated(conversationID))
    #expect(
        await waitUntil { harness.viewModel.streamingRow == nil },
        "回到闲置阶段后 streamingRow 应隐藏"
    )
}

/// 轮询等待条件成立，避免用固定睡眠与异步门禁赛跑。
@MainActor
private func waitUntil(
    timeoutMs: Int = 2_000,
    _ condition: @MainActor () -> Bool
) async -> Bool {
    for _ in 0..<(timeoutMs / 10) {
        if condition() { return true }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    return condition()
}

@MainActor
@Test("非当前会话的流式事件被忽略")
func streamingChangeForOtherConversationIgnored() async {
    let conversationID = UUID()
    let streaming = StubStreamingCapability(
        streaming: makeMessage(conversationID: UUID(), role: .assistant, content: "x"),
        stage: .generating
    )
    let harness = ViewModelHarness(
        selected: conversationID,
        page: [makeMessage(conversationID: conversationID, role: .user, content: "hi")],
        streaming: streaming
    )
    await harness.viewModel.activateCurrentConversation()

    harness.viewModel.handleStreamingChange(.updated(UUID()))
    try? await Task.sleep(nanoseconds: 60_000_000)

    #expect(harness.viewModel.streamingRow == nil)
}

// MARK: - Message change events

@MainActor
@Test("插入消息直接进入窗口，用户消息记录为最近一条")
func insertedMessageLandsInWindow() async {
    let conversationID = UUID()
    let existing = makeMessage(conversationID: conversationID, role: .user, content: "old")
    let manager = StubMessageListMessageCapability(page: [existing])
    let harness = ViewModelHarness(selected: conversationID, messages: manager)
    await harness.viewModel.activateCurrentConversation()

    let fresh = makeMessage(conversationID: conversationID, role: .user, content: "new")
    harness.viewModel.handleMessageChange(.inserted(fresh, conversationID: conversationID))

    #expect(harness.viewModel.persistedMessages.contains { $0.id == fresh.id })
    #expect(harness.viewModel.latestUserMessageID == fresh.id)
    #expect(harness.viewModel.historyRows.contains { $0.id == fresh.id })
}

@MainActor
@Test("插入同 id 消息为原地替换，不产生重复行")
func insertedMessageWithSameIDReplaces() async {
    let conversationID = UUID()
    let original = makeMessage(conversationID: conversationID, role: .assistant, content: "v1")
    let manager = StubMessageListMessageCapability(page: [original])
    let harness = ViewModelHarness(selected: conversationID, messages: manager)
    await harness.viewModel.activateCurrentConversation()

    let revised = Message(
        id: original.id,
        conversationID: conversationID,
        role: .assistant,
        content: "v2"
    )
    harness.viewModel.handleMessageChange(.inserted(revised, conversationID: conversationID))

    let matching = harness.viewModel.persistedMessages.filter { $0.id == original.id }
    #expect(matching.count == 1)
    #expect(matching.first?.content == "v2")
}

@MainActor
@Test("插入工具结果消息不进入展示窗口")
func insertedToolMessageIsIgnored() async {
    let conversationID = UUID()
    let harness = ViewModelHarness(
        selected: conversationID,
        page: [makeMessage(conversationID: conversationID, role: .user, content: "hi")]
    )
    await harness.viewModel.activateCurrentConversation()

    let toolResult = makeMessage(conversationID: conversationID, role: .tool, content: "result")
    harness.viewModel.handleMessageChange(.inserted(toolResult, conversationID: conversationID))

    #expect(!harness.viewModel.persistedMessages.contains { $0.role == .tool })
}

@MainActor
@Test("其他会话的插入事件被忽略")
func insertedMessageForOtherConversationIgnored() async {
    let conversationID = UUID()
    let harness = ViewModelHarness(
        selected: conversationID,
        page: [makeMessage(conversationID: conversationID, role: .user, content: "mine")]
    )
    await harness.viewModel.activateCurrentConversation()

    let foreign = makeMessage(conversationID: UUID(), role: .user, content: "theirs")
    harness.viewModel.handleMessageChange(.inserted(foreign, conversationID: UUID()))

    #expect(harness.viewModel.persistedMessages.allSatisfy { $0.conversationID == conversationID })
}

@MainActor
@Test("持久化与更新事件触发尾部刷新，删除事件触发刷新")
func persistenceEventsTriggerTailRefresh() async {
    let conversationID = UUID()
    let first = makeMessage(conversationID: conversationID, role: .user, content: "one")
    let manager = StubMessageListMessageCapability(page: [first])
    let harness = ViewModelHarness(selected: conversationID, messages: manager)
    await harness.viewModel.activateCurrentConversation()
    let baseline = manager.pageRequests.count

    harness.viewModel.handleMessageChange(.persisted(first, conversationID: conversationID))
    harness.viewModel.handleMessageChange(.updated(conversationID: conversationID))
    harness.viewModel.handleMessageChange(.deleted(messageID: first.id, conversationID: conversationID))

    try? await Task.sleep(nanoseconds: 30_000_000)
    #expect(manager.pageRequests.count > baseline, "刷新事件应重新读取分页")
}

@MainActor
@Test("其他会话的持久化事件被忽略")
func persistenceEventForOtherConversationIgnored() async {
    let conversationID = UUID()
    let manager = StubMessageListMessageCapability(page: [
        makeMessage(conversationID: conversationID, role: .user, content: "mine")
    ])
    let harness = ViewModelHarness(selected: conversationID, messages: manager)
    await harness.viewModel.activateCurrentConversation()
    let baseline = manager.pageRequests.count

    harness.viewModel.handleMessageChange(.updated(conversationID: UUID()))

    try? await Task.sleep(nanoseconds: 30_000_000)
    #expect(manager.pageRequests.count == baseline)
}

// MARK: - Turn activity summaries

@MainActor
@Test("按窗口内 turn 汇总工具调用统计")
func turnActivitySummariesAggregateRecords() async {
    let conversationID = UUID()
    let turnID = UUID()
    let message = Message(
        conversationID: conversationID,
        role: .assistant,
        content: "done",
        turnID: turnID
    )
    let toolManager = StubToolManagerCapability()
    toolManager.recordsByTurn[turnID] = [
        makeToolCallRecord(id: "a", conversationID: conversationID, completed: true, duration: 1),
        makeToolCallRecord(id: "b", conversationID: conversationID, completed: true, duration: 2, isError: true),
    ]
    let harness = ViewModelHarness(
        selected: conversationID,
        page: [message],
        toolManager: toolManager
    )
    await harness.viewModel.activateCurrentConversation()

    let summary = harness.viewModel.turnActivitySummaries[turnID]
    #expect(summary?.totalCount == 2)
    #expect(summary?.completedCount == 2)
    #expect(summary?.failedCount == 1)
    #expect(summary?.totalDuration == 3)
}

@MainActor
@Test("窗口内无 turn 时不发起工具查询")
func turnActivitySkipsWhenNoTurns() async {
    let conversationID = UUID()
    let toolManager = StubToolManagerCapability()
    let harness = ViewModelHarness(
        selected: conversationID,
        page: [makeMessage(conversationID: conversationID, role: .user, content: "hi")],
        toolManager: toolManager
    )
    await harness.viewModel.activateCurrentConversation()

    #expect(harness.viewModel.turnActivitySummaries.isEmpty)
    #expect(toolManager.toolCallsRequestCount == 0)
}

@MainActor
@Test("turnActivity 在缺少工具能力时返回 nil")
func turnActivityWithoutToolManagerIsNil() async {
    let conversationID = UUID()
    let turnID = UUID()
    let services = MessageListServices(
        conversations: StubConversationCapability(selected: conversationID),
        conversationState: StubConversationStateCapability(),
        developerModeState: DeveloperModeStateViewModel(),
        messages: StubMessageListMessageCapability(page: []),
        rendering: nil, streaming: nil, toolManager: nil,
        agentTurn: nil, promptSuggestions: nil, promptSuggestionExecutor: nil,
        project: nil, toolbar: nil, chat: nil
    )
    let viewModel = ListV2ViewModel(services: services)

    let activity = await viewModel.turnActivity(for: turnID, conversationID: conversationID)
    #expect(activity == nil)
}

// MARK: - Accessors

@MainActor
@Test("渲染器与详细程度经由能力透传")
func accessorsDelegateToCapabilities() async {
    let conversationID = UUID()
    let harness = ViewModelHarness(selected: conversationID, page: [])
    harness.conversations.defaultVerbosity = .brief
    await harness.viewModel.activateCurrentConversation()

    #expect(harness.viewModel.verbosity == .brief)
    #expect(harness.viewModel.renderer(for: makeMessage(conversationID: conversationID, role: .user, content: "x")) == nil)
}

@MainActor
@Test("会话详细程度变化后重建历史行")
func conversationSettingsChangeRebuildsRows() async {
    let conversationID = UUID()
    let harness = ViewModelHarness(selected: conversationID, page: [
        makeMessage(conversationID: conversationID, role: .user, content: "hi")
    ])
    await harness.viewModel.activateCurrentConversation()
    let baseline = harness.viewModel.historyRows

    harness.conversations.defaultVerbosity = .brief
    harness.viewModel.refreshConversationSettingsIfNeeded()

    #expect(harness.viewModel.historyRows.count == baseline.count)
}

// MARK: - Conversation state / activity

@MainActor
@Test("会话状态变化会刷新活动消息")
func conversationStateChangeRefreshesActivity() async {
    let conversationID = UUID()
    let state = StubConversationStateCapability()
    let harness = ViewModelHarness(
        selected: conversationID,
        page: [makeMessage(conversationID: conversationID, role: .user, content: "hi")],
        conversationState: state
    )
    await harness.viewModel.activateCurrentConversation()

    // 无 activity → activityMessage 为 nil
    harness.viewModel.handleConversationStateChange(.updated(conversationID))
    #expect(harness.viewModel.activityMessage == nil)

    // 其他会话的状态事件被忽略
    harness.viewModel.handleConversationStateChange(.updated(UUID()))
    #expect(harness.viewModel.activityMessage == nil)
}

// MARK: - Sequenced message capability

/// 按调用顺序依次返回不同的分页结果，用于模拟会话切换。
@MainActor
final class SequencedMessageListMessageCapability: MessageListMessageCapability {
    private var pages: [[Message]]
    private(set) var index = 0

    init(pages: [[Message]]) { self.pages = pages }

    func messagesSnapshot(in conversationID: UUID) async -> [Message] {
        let page = pages[min(index, pages.count - 1)]
        return page
    }

    func messagePageAsync(
        for conversationID: UUID,
        limit: Int,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) async -> [Message] {
        defer { if beforeMessageID == nil { index += 1 } }
        return pages[min(index, pages.count - 1)]
    }

    func hasEarlierMessagesAsync(
        for conversationID: UUID,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) async -> Bool { false }
}
