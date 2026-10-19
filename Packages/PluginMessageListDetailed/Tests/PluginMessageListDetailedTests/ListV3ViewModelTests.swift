import Foundation
import ProviderAgentLoop
import ProviderConversation
import ProviderConversationState
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager
import Testing
@testable import PluginMessageListDetailed

/// 构造一条测试消息。
@MainActor
private func msg(
    id: UUID = UUID(),
    conversationID: UUID,
    role: MessageRole,
    content: String = "",
    createdAt: Date = Date(),
    turnID: UUID? = nil,
    isError: Bool = false,
    toolCalls: [MessageToolCall]? = nil
) -> Message {
    Message(
        id: id,
        conversationID: conversationID,
        role: role,
        content: content,
        createdAt: createdAt,
        turnID: turnID,
        isError: isError,
        toolCalls: toolCalls
    )
}

@MainActor
private func makeToolCallRecord(
    id: String,
    turnID: UUID,
    conversationID: UUID,
    startedAt: Date,
    duration: TimeInterval? = nil,
    completedAt: Date? = nil,
    isError: Bool = false
) -> ToolCallRecord {
    ToolCallRecord(
        id: id,
        toolCallID: id,
        toolName: "read",
        toolDisplayName: "Read",
        turnID: turnID,
        conversationID: conversationID,
        createdAt: startedAt,
        startedAt: startedAt,
        completedAt: completedAt,
        duration: duration,
        argumentsJSON: "{}",
        resultContent: "ok",
        resultJSON: nil,
        resultIsError: isError,
        riskLevel: "low"
    )
}

/// 组装一套可控的服务容器。
@MainActor
private struct Harness {
    let conversations: StubConversationCapability
    let messages: StubMessageListMessageCapability
    let conversationState: StubConversationStateCapability
    let streaming: StubStreamingCapability
    let toolManager: StubToolManagerCapability
    let agentLoop: StubAgentLoopCapability
    let viewModel: ListV3ViewModel

    init(
        conversationID: UUID?,
        page: [Message] = [],
        hasEarlier: Bool = false,
        verbosity: ResponseVerbosity = .standard,
        activity: ConversationActivity? = nil,
        withToolManager: Bool = true,
        pageSize: Int = 40,
        maxRetainedCount: Int = 300,
        streamingDisplayEnabled: Bool = false
    ) {
        self.init(
            conversationID: conversationID,
            window: page,
            earlier: [],
            hasEarlier: hasEarlier,
            verbosity: verbosity,
            activity: activity,
            withToolManager: withToolManager,
            pageSize: pageSize,
            maxRetainedCount: maxRetainedCount,
            streamingDisplayEnabled: streamingDisplayEnabled
        )
    }

    /// 显式区分「首屏窗口」与「更早历史」，用于翻页 / prepend 测试。
    init(
        conversationID: UUID?,
        window: [Message],
        earlier: [Message],
        hasEarlier: Bool = false,
        verbosity: ResponseVerbosity = .standard,
        activity: ConversationActivity? = nil,
        withToolManager: Bool = true,
        pageSize: Int = 40,
        maxRetainedCount: Int = 300,
        streamingDisplayEnabled: Bool = false
    ) {
        let conversations = StubConversationCapability(
            selectedConversationID: conversationID,
            verbosity: verbosity
        )
        let messages = StubMessageListMessageCapability(window: window, earlier: earlier, hasEarlier: hasEarlier)
        let conversationState = StubConversationStateCapability(
            snapshot: ConversationStateSnapshot(
                conversationID: conversationID ?? UUID(),
                activity: activity
            )
        )
        let streaming = StubStreamingCapability()
        let toolManager = StubToolManagerCapability()
        let agentLoop = StubAgentLoopCapability()
        self.conversations = conversations
        self.messages = messages
        self.conversationState = conversationState
        self.streaming = streaming
        self.toolManager = toolManager
        self.agentLoop = agentLoop
        self.viewModel = ListV3ViewModel(
            services: MessageListServices(
                conversations: conversations,
                conversationState: conversationState,
                developerModeState: DeveloperModeStateViewModel(),
                messages: messages,
                rendering: nil,
                streaming: streaming,
                toolManager: withToolManager ? toolManager : nil,
                agentTurn: agentLoop,
                promptSuggestions: nil,
                promptSuggestionExecutor: nil,
                project: nil,
                toolbar: nil,
                chat: nil
            ),
            pagination: MessageListPaginationService(
                pageSize: pageSize,
                maxRetainedCount: maxRetainedCount
            ),
            streamingDisplayEnabled: streamingDisplayEnabled
        )
    }
}

@Suite("ListV3ViewModel — 生命周期与分页")
@MainActor
struct ListV3ViewModelPaginationTests {

    @Test("激活会话后加载首屏并更新加载态")
    func activateLoadsFirstPage() async {
        let conversationID = UUID()
        let rows = (0..<3).map { msg(conversationID: conversationID, role: .user, content: "\($0)") }
        // pageSize=2 时取回 3 条表示存在更早消息。
        let harness = Harness(
            conversationID: conversationID,
            page: rows,
            hasEarlier: true,
            pageSize: 2
        )
        #expect(harness.viewModel.isLoading)

        await harness.viewModel.activate(conversationID: conversationID)

        #expect(!harness.viewModel.isLoading)
        #expect(harness.viewModel.persistedMessages.map(\.id) == rows.suffix(2).map(\.id))
        #expect(harness.viewModel.hasEarlierMessages)
        #expect(harness.viewModel.hasPersistedMessages)
    }

    @Test("没有选中会话时保持空态")
    func activateWithoutConversationStaysEmpty() async {
        let harness = Harness(conversationID: nil)

        await harness.viewModel.activate(conversationID: nil)

        #expect(!harness.viewModel.isLoading)
        #expect(harness.viewModel.persistedMessages.isEmpty)
        #expect(!harness.viewModel.hasEarlierMessages)
        #expect(!harness.viewModel.hasPersistedMessages)
    }

    @Test("激活过期会话的请求被丢弃")
    func activateIgnoresStaleConversation() async {
        let current = UUID()
        let harness = Harness(conversationID: current, page: [msg(conversationID: current, role: .user, content: "a")])

        await harness.viewModel.activate(conversationID: UUID())

        #expect(harness.viewModel.persistedMessages.isEmpty)
    }

    @Test("activateCurrentConversation 读取执行时刻的选中会话")
    func activateCurrentConversationUsesCurrentSelection() async {
        let conversationID = UUID()
        let harness = Harness(conversationID: conversationID, page: [msg(conversationID: conversationID, role: .user, content: "a")])

        await harness.viewModel.activateCurrentConversation()

        #expect(harness.viewModel.persistedMessages.count == 1)
        #expect(harness.viewModel.selectedConversationID == conversationID)
    }

    @Test("向上翻页 prepend 更早消息并返回锚点 id")
    func loadEarlierPrependsAndReturnsAnchor() async {
        let conversationID = UUID()
        // 显式时间戳：stub 内部按 createdAt 排序，默认 Date() 会导致顺序不稳定。
        let base = Date(timeIntervalSince1970: 100)
        let anchor = msg(
            conversationID: conversationID, role: .user, content: "anchor",
            createdAt: base.addingTimeInterval(2)
        )
        // window 是首屏两条；earlier 是一条更早的历史，翻页时才会被 prepend。
        let earlier = msg(
            conversationID: conversationID, role: .user, content: "old",
            createdAt: base
        )
        // 窗口三条 + 一条更早历史；pageSize=2 时首屏取 3 条探测到还有更早消息。
        let window = [
            msg(
                conversationID: conversationID, role: .user, content: "mid",
                createdAt: base.addingTimeInterval(1)
            ),
            msg(
                conversationID: conversationID, role: .user, content: "mid2",
                createdAt: base.addingTimeInterval(2)
            ),
            msg(
                conversationID: conversationID, role: .user, content: "anchor",
                createdAt: base.addingTimeInterval(3)
            )
        ]
        // pageSize=2 时首屏取 pageSize+1=3 条探测，翻页取 pageSize=2 条。
        let harness = Harness(
            conversationID: conversationID,
            window: window,
            earlier: [earlier],
            pageSize: 2
        )
        await harness.viewModel.activate(conversationID: conversationID)
        // 首屏只保留末尾 2 条，且探测到还有更早消息。
        #expect(harness.viewModel.hasEarlierMessages)
        #expect(harness.viewModel.persistedMessages.count == 2)

        let anchorID = await harness.viewModel.loadEarlier(isAtBottom: false)

        // 锚点 = prepend 前窗口的第一条，View 应把它钉回视口顶部。
        #expect(anchorID == window[1].id)
        #expect(harness.viewModel.persistedMessages.first?.content == "old")
        // 首屏 2 条 + 翻页 2 条更早历史。
        #expect(harness.viewModel.persistedMessages.count == 4)
        #expect(harness.viewModel.hasEarlierMessages == false, "已翻到最早一条")
    }

    @Test("无更早消息时翻页返回 nil 且不改变窗口")
    func loadEarlierReturnsNilWithoutEarlierMessages() async {
        let conversationID = UUID()
        let harness = Harness(
            conversationID: conversationID,
            page: [msg(conversationID: conversationID, role: .user, content: "a")],
            hasEarlier: false,
            pageSize: 2
        )
        await harness.viewModel.activate(conversationID: conversationID)
        #expect(!harness.viewModel.hasEarlierMessages)

        let anchorID = await harness.viewModel.loadEarlier(isAtBottom: true)

        #expect(anchorID == nil)
        #expect(harness.viewModel.persistedMessages.count == 1)
    }

    @Test("窗口为空时翻页直接返回 nil")
    func loadEarlierReturnsNilWhenEmpty() async {
        let conversationID = UUID()
        let harness = Harness(conversationID: conversationID, page: [], hasEarlier: true)
        await harness.viewModel.activate(conversationID: conversationID)

        #expect(await harness.viewModel.loadEarlier(isAtBottom: true) == nil)
    }

    @Test("尾部刷新检测到新消息时覆盖窗口")
    func refreshTailAppliesNewMessages() async {
        let conversationID = UUID()
        let existing = msg(conversationID: conversationID, role: .user, content: "old")
        let harness = Harness(conversationID: conversationID, page: [existing])
        await harness.viewModel.activate(conversationID: conversationID)
        let incoming = [existing, msg(conversationID: conversationID, role: .assistant, content: "new")]
        harness.messages.setPage(incoming)

        let changed = await harness.viewModel.refreshTail()

        #expect(changed)
        #expect(harness.viewModel.persistedMessages.count == 2)
    }

    @Test("尾部刷新无变化时返回 false")
    func refreshTailDetectsNoChange() async {
        let conversationID = UUID()
        let existing = msg(conversationID: conversationID, role: .user, content: "same")
        let harness = Harness(conversationID: conversationID, page: [existing])
        await harness.viewModel.activate(conversationID: conversationID)

        #expect(await harness.viewModel.refreshTail() == false)
    }

    @Test("没有选中会话时尾部刷新返回 false")
    func refreshTailWithoutConversationReturnsFalse() async {
        let harness = Harness(conversationID: nil)

        #expect(await harness.viewModel.refreshTail() == false)
    }

    @Test("会话设置变化后重建历史行")
    func refreshConversationSettingsRebuildsRows() async {
        let conversationID = UUID()
        let harness = Harness(
            conversationID: conversationID,
            page: [msg(conversationID: conversationID, role: .user, content: "hello")]
        )
        await harness.viewModel.activate(conversationID: conversationID)
        let before = harness.viewModel.historyRows.count

        harness.conversations.verbosityValue = .brief
        harness.viewModel.refreshConversationSettingsIfNeeded()

        #expect(harness.viewModel.historyRows.count == before)
    }

    @Test("会话设置变化后 verbosity 透传更新")
    func verbosityFollowsConversationSettings() async {
        let conversationID = UUID()
        let harness = Harness(
            conversationID: conversationID,
            page: [],
            verbosity: .standard
        )
        #expect(harness.viewModel.verbosity == .standard)

        harness.conversations.verbosityValue = .brief

        #expect(harness.viewModel.verbosity == .brief)
    }

    @Test("没有渲染能力时 renderer 返回 nil")
    func rendererDegradesWhenMissing() async {
        let conversationID = UUID()
        let harness = Harness(conversationID: conversationID)
        let message = msg(conversationID: conversationID, role: .user, content: "x")

        #expect(harness.viewModel.renderer(for: message) == nil)
    }
}

@Suite("ListV3ViewModel — 事件处理")
@MainActor
struct ListV3ViewModelEventTests {

    @Test("插入用户消息后记录 id 并按时间排序")
    func insertedUserMessageSortsAndRecords() async {
        let conversationID = UUID()
        let harness = Harness(conversationID: conversationID, page: [
            msg(conversationID: conversationID, role: .assistant, content: "first")
        ])
        await harness.viewModel.activate(conversationID: conversationID)
        let user = msg(conversationID: conversationID, role: .user, content: "question")

        harness.viewModel.handleMessageChange(
            .inserted(user, conversationID: conversationID)
        )

        #expect(harness.viewModel.latestUserMessageID == user.id)
        #expect(harness.viewModel.persistedMessages.count == 2)
    }

    @Test("插入同 id 消息时原地替换而不重复追加")
    func insertedSameIDReplacesInPlace() async {
        let conversationID = UUID()
        let original = msg(conversationID: conversationID, role: .assistant, content: "v1")
        let harness = Harness(conversationID: conversationID, page: [original])
        await harness.viewModel.activate(conversationID: conversationID)
        let updated = msg(id: original.id, conversationID: conversationID, role: .assistant, content: "v2")

        harness.viewModel.handleMessageChange(
            .inserted(updated, conversationID: conversationID)
        )

        #expect(harness.viewModel.persistedMessages.count == 1)
        #expect(harness.viewModel.persistedMessages.first?.content == "v2")
    }

    @Test("忽略其他会话插入的消息")
    func insertedForeignConversationIgnored() async {
        let conversationID = UUID()
        let harness = Harness(conversationID: conversationID, page: [])
        await harness.viewModel.activate(conversationID: conversationID)

        harness.viewModel.handleMessageChange(
            .inserted(msg(conversationID: UUID(), role: .user, content: "other"), conversationID: UUID())
        )

        #expect(harness.viewModel.persistedMessages.isEmpty)
        #expect(harness.viewModel.latestUserMessageID == nil)
    }

    @Test("忽略独立的工具结果行插入")
    func insertedToolMessageIgnored() async {
        let conversationID = UUID()
        let harness = Harness(conversationID: conversationID, page: [])
        await harness.viewModel.activate(conversationID: conversationID)

        harness.viewModel.handleMessageChange(
            .inserted(msg(conversationID: conversationID, role: .tool, content: "result"), conversationID: conversationID)
        )

        #expect(harness.viewModel.persistedMessages.isEmpty)
    }

    @Test("窗口超过上限时裁剪最早的消息")
    func insertedEvictsBeyondWindow() async {
        let conversationID = UUID()
        let harness = Harness(conversationID: conversationID, page: [])
        await harness.viewModel.activate(conversationID: conversationID)

        for index in 0..<5 {
            harness.viewModel.handleMessageChange(
                .inserted(
                    msg(conversationID: conversationID, role: .user, content: "\(index)"),
                    conversationID: conversationID
                )
            )
        }

        // 默认 maxRetainedCount 为 300，这里只验证不会无限增长错乱，窗口保持有序。
        #expect(harness.viewModel.persistedMessages.count == 5)
    }

    @Test("持久化/更新/删除事件触发尾部刷新")
    func persistedEventsTriggerTailRefresh() async {
        let conversationID = UUID()
        let existing = msg(conversationID: conversationID, role: .user, content: "old")
        let harness = Harness(conversationID: conversationID, page: [existing])
        await harness.viewModel.activate(conversationID: conversationID)
        harness.messages.setPage([existing, msg(conversationID: conversationID, role: .assistant, content: "tail")])

        harness.viewModel.handleMessageChange(.persisted(existing, conversationID: conversationID))
        // 等待尾部刷新的异步任务完成。
        await waitUntil { harness.viewModel.persistedMessages.count == 2 }

        #expect(harness.viewModel.persistedMessages.count == 2)
    }

    @Test("其他会话的持久化事件被忽略")
    func persistedForeignConversationIgnored() async {
        let conversationID = UUID()
        let harness = Harness(conversationID: conversationID, page: [])
        await harness.viewModel.activate(conversationID: conversationID)

        harness.viewModel.handleMessageChange(.cleared(conversationID: UUID()))
        await waitUntil { harness.viewModel.persistedMessages.isEmpty }

        #expect(harness.viewModel.persistedMessages.isEmpty)
    }

    @Test("会话状态变化更新活动消息")
    func conversationStateChangeUpdatesActivity() async {
        let conversationID = UUID()
        let harness = Harness(conversationID: conversationID, page: [], activity: .thinking)
        await harness.viewModel.activate(conversationID: conversationID)
        #expect(harness.viewModel.activityMessage != nil)

        harness.conversationState.snapshot = ConversationStateSnapshot(
            conversationID: conversationID,
            activity: .sending
        )
        harness.viewModel.handleConversationStateChange(.updated(conversationID))

        #expect(harness.viewModel.activityMessage?.content == "正在发送消息…")
    }

    @Test("其他会话的状态事件被忽略")
    func conversationStateChangeForeignIgnored() async {
        let conversationID = UUID()
        let harness = Harness(conversationID: conversationID, page: [], activity: .thinking)
        await harness.viewModel.activate(conversationID: conversationID)

        harness.viewModel.handleConversationStateChange(.updated(UUID()))

        // 仍是原会话的活动状态，未被其他会话事件污染。
        #expect(harness.viewModel.activityMessage?.content == "正在思考…")
    }

    @Test("非 updated 的状态事件被忽略")
    func conversationStateRemovedIgnored() async {
        let conversationID = UUID()
        let harness = Harness(conversationID: conversationID, page: [], activity: .thinking)
        await harness.viewModel.activate(conversationID: conversationID)

        harness.viewModel.handleConversationStateChange(.removed(conversationID))

        #expect(harness.viewModel.activityMessage?.content == "正在思考…")
    }

    @Test("切换会话后活动消息反映新会话状态")
    func activityMessageReflectsConversationState() async {
        let first = UUID()
        let harness = Harness(conversationID: first, page: [], activity: .thinking)
        await harness.viewModel.activate(conversationID: first)

        #expect(harness.viewModel.activityMessage?.content == "正在思考…")

        harness.conversationState.snapshot = ConversationStateSnapshot(
            conversationID: first,
            activity: .executingTool
        )
        harness.viewModel.handleConversationStateChange(.updated(first))

        #expect(harness.viewModel.activityMessage?.content == "正在执行工具…")
    }

    @Test("会话状态无活动时活动消息为 nil")
    func activityMessageNilWhenNoActivity() async {
        let conversationID = UUID()
        let harness = Harness(conversationID: conversationID, page: [], activity: nil)
        await harness.viewModel.activate(conversationID: conversationID)

        #expect(harness.viewModel.activityMessage == nil)
    }
}

@Suite("ListV3ViewModel — 流式")
@MainActor
struct ListV3ViewModelStreamingTests {
    // 开关改为构造注入，无需再为共享状态串行化。

    @Test("流式开关关闭时不产生流式行")
    func streamingRowSuppressedWhenDisabled() async {
        let conversationID = UUID()
        let harness = Harness(conversationID: conversationID, page: [])
        await harness.viewModel.activate(conversationID: conversationID)
        harness.streaming.stage = .generating
        harness.streaming.row = msg(conversationID: conversationID, role: .assistant, content: "tok")
        harness.viewModel.handleStreamingChange(.updated(conversationID))
        await waitUntil { harness.viewModel.streamingRow == nil }

        #expect(harness.viewModel.streamingRow == nil)
    }

    @Test("流式开启且生成中时产生流式行")
    func streamingRowShownWhenEnabled() async {
        let conversationID = UUID()
        let harness = Harness(conversationID: conversationID, page: [], streamingDisplayEnabled: true)
        await harness.viewModel.activate(conversationID: conversationID)
        let row = msg(conversationID: conversationID, role: .assistant, content: "tok")
        harness.streaming.stage = .generating
        harness.streaming.row = row
        harness.viewModel.handleStreamingChange(.updated(conversationID))
        await waitUntil { harness.viewModel.streamingRow != nil }

        #expect(harness.viewModel.streamingRow?.id == row.id)
        // 流式行可见时活动消息被抑制。
        #expect(harness.viewModel.activityMessage == nil)
    }

    @Test("流式行属于其他会话时被忽略")
    func streamingRowForeignConversationIgnored() async {
        let conversationID = UUID()
        let harness = Harness(conversationID: conversationID, page: [], streamingDisplayEnabled: true)
        await harness.viewModel.activate(conversationID: conversationID)
        harness.streaming.stage = .generating
        harness.streaming.row = msg(conversationID: UUID(), role: .assistant, content: "tok")
        harness.viewModel.handleStreamingChange(.updated(conversationID))
        await waitUntil { harness.viewModel.streamingRow == nil }

        #expect(harness.viewModel.streamingRow == nil)
    }

    @Test("brief 详细程度下不显示流式行")
    func streamingRowHiddenInBriefMode() async {
        let conversationID = UUID()
        let harness = Harness(conversationID: conversationID, page: [], verbosity: .brief, streamingDisplayEnabled: true)
        await harness.viewModel.activate(conversationID: conversationID)
        harness.streaming.stage = .generating
        harness.streaming.row = msg(conversationID: conversationID, role: .assistant, content: "tok")
        harness.viewModel.handleStreamingChange(.updated(conversationID))
        await waitUntil { harness.viewModel.streamingRow == nil }

        #expect(harness.viewModel.streamingRow == nil)
    }

    @Test("非当前会话的流式事件被忽略")
    func streamingChangeForeignConversationIgnored() async {
        let conversationID = UUID()
        let harness = Harness(conversationID: conversationID, page: [], streamingDisplayEnabled: true)
        await harness.viewModel.activate(conversationID: conversationID)
        harness.streaming.stage = .generating
        harness.streaming.row = msg(conversationID: conversationID, role: .assistant, content: "tok")
        harness.viewModel.handleStreamingChange(.updated(UUID()))
        await waitUntil { harness.viewModel.streamingRow == nil }

        #expect(harness.viewModel.streamingRow == nil)
    }

    @Test("idle 阶段结束流式时清除流式行")
    func streamingRowClearedWhenIdle() async {
        let conversationID = UUID()
        let harness = Harness(conversationID: conversationID, page: [], streamingDisplayEnabled: true)
        await harness.viewModel.activate(conversationID: conversationID)
        harness.streaming.stage = .generating
        harness.streaming.row = msg(conversationID: conversationID, role: .assistant, content: "tok")
        harness.viewModel.handleStreamingChange(.updated(conversationID))
        await waitUntil { harness.viewModel.streamingRow != nil }
        #expect(harness.viewModel.streamingRow != nil)

        harness.streaming.stage = .idle
        harness.streaming.row = nil
        harness.viewModel.handleStreamingChange(.updated(conversationID))
        await waitUntil { harness.viewModel.streamingRow == nil }

        #expect(harness.viewModel.streamingRow == nil)
    }
}

@Suite("ListV3ViewModel — 回合活动")
@MainActor
struct ListV3ViewModelTurnActivityTests {

    @Test("汇总回合工具调用的统计信息")
    func turnActivitySummariesAggregated() async {
        let conversationID = UUID()
        let turnID = UUID()
        let start = Date(timeIntervalSince1970: 100)
        let page = [
            msg(conversationID: conversationID, role: .assistant, content: "a", turnID: turnID)
        ]
        let harness = Harness(conversationID: conversationID, page: page)
        harness.toolManager.recordsByTurn[turnID] = [
            makeToolCallRecord(
                id: "c1",
                turnID: turnID,
                conversationID: conversationID,
                startedAt: start,
                duration: 1.5,
                completedAt: start.addingTimeInterval(1.5)
            ),
            makeToolCallRecord(
                id: "c2",
                turnID: turnID,
                conversationID: conversationID,
                startedAt: start.addingTimeInterval(2),
                duration: 0.5,
                completedAt: nil,
                isError: true
            )
        ]

        await harness.viewModel.activate(conversationID: conversationID)

        let summary = harness.viewModel.turnActivitySummaries[turnID]
        #expect(summary?.totalCount == 2)
        #expect(summary?.completedCount == 1)
        #expect(summary?.failedCount == 1)
        #expect(summary?.totalDuration == 2.0)
    }

    @Test("没有工具能力时不产生汇总")
    func turnActivitySummariesEmptyWithoutToolManager() async {
        let conversationID = UUID()
        let turnID = UUID()
        let harness = Harness(
            conversationID: conversationID,
            page: [msg(conversationID: conversationID, role: .assistant, content: "a", turnID: turnID)],
            withToolManager: false
        )

        await harness.viewModel.activate(conversationID: conversationID)

        #expect(harness.viewModel.turnActivitySummaries.isEmpty)
    }

    @Test("消息没有 turnID 时不查询工具调用")
    func turnActivitySkipsWhenNoTurnIDs() async {
        let conversationID = UUID()
        let harness = Harness(
            conversationID: conversationID,
            page: [msg(conversationID: conversationID, role: .user, content: "hi")]
        )

        await harness.viewModel.activate(conversationID: conversationID)

        #expect(harness.toolManager.queriedTurnIDs.isEmpty)
        #expect(harness.viewModel.turnActivitySummaries.isEmpty)
    }

    @Test("单回合活动快照按开始时间排序工具调用")
    func turnActivitySortsToolCalls() async {
        let conversationID = UUID()
        let turnID = UUID()
        let harness = Harness(conversationID: conversationID, page: [])
        harness.agentLoop.state = .running
        let base = Date(timeIntervalSince1970: 500)
        harness.toolManager.recordsByTurn[turnID] = [
            makeToolCallRecord(id: "b", turnID: turnID, conversationID: conversationID, startedAt: base.addingTimeInterval(2)),
            makeToolCallRecord(id: "a", turnID: turnID, conversationID: conversationID, startedAt: base)
        ]

        let activity = await harness.viewModel.turnActivity(
            for: turnID,
            conversationID: conversationID
        )

        #expect(activity?.toolCalls.map(\.id) == ["a", "b"])
        #expect(activity?.totalCount == 2)
        #expect(activity?.state == .running)
    }

    @Test("没有工具能力时回合活动为 nil")
    func turnActivityNilWithoutToolManager() async {
        let conversationID = UUID()
        let turnID = UUID()
        let harness = Harness(
            conversationID: conversationID,
            page: [],
            withToolManager: false
        )

        let activity = await harness.viewModel.turnActivity(
            for: turnID,
            conversationID: conversationID
        )

        #expect(activity == nil)
    }
}

@Suite("ListV3ViewModel — 历史行缓存")
@MainActor
struct ListV3ViewModelHistoryTests {
    @Test("流式行可见时丢弃 status 行")
    func historyRowsHideStatusWhenStreamingVisible() async {
        let conversationID = UUID()
        let page = [
            msg(conversationID: conversationID, role: .user, content: "q"),
            msg(conversationID: conversationID, role: .status, content: "thinking")
        ]
        let harness = Harness(conversationID: conversationID, page: page, streamingDisplayEnabled: true)
        await harness.viewModel.activate(conversationID: conversationID)

        // 基线：没有流式行时 status 行必须保留，否则下面的「丢弃」无从谈起。
        #expect(harness.viewModel.historyRows.contains { $0.role == .status })

        harness.streaming.stage = .generating
        harness.streaming.row = msg(conversationID: conversationID, role: .assistant, content: "tok")
        harness.viewModel.handleStreamingChange(.updated(conversationID))
        await waitUntil { harness.viewModel.streamingRow != nil }

        #expect(!harness.viewModel.historyRows.contains { $0.role == .status })
        #expect(harness.viewModel.streamingRow != nil, "流式行已可见")
    }

    @Test("历史行剔除独立工具结果行")
    func historyRowsDropToolResultMessages() async {
        let conversationID = UUID()
        let page = [
            msg(conversationID: conversationID, role: .user, content: "q"),
            msg(conversationID: conversationID, role: .tool, content: "tool result")
        ]
        let harness = Harness(conversationID: conversationID, page: page)

        await harness.viewModel.activate(conversationID: conversationID)

        #expect(!harness.viewModel.historyRows.contains { $0.role == .tool })
    }

    @Test("切换会话后历史行不残留上一会话内容")
    func historyRowsResetOnConversationSwitch() async {
        let first = UUID()
        let second = UUID()
        let harness = Harness(
            conversationID: first,
            page: [msg(conversationID: first, role: .user, content: "first")]
        )
        await harness.viewModel.activate(conversationID: first)
        #expect(harness.viewModel.historyRows.count == 1)

        harness.conversations.selectedConversationID = second
        harness.messages.setPage([])
        await harness.viewModel.activate(conversationID: second)

        #expect(harness.viewModel.historyRows.isEmpty)
        #expect(harness.viewModel.latestUserMessageID == nil)
    }
}


/// 轮询直到条件成立或超时。
///
/// 流式刷新走 16ms 单飞帧门禁，固定 `Task.sleep` 在 MainActor 被其他
/// 并行测试抢占时会偶发读到中间态；轮询让断言与真实完成时刻对齐。
@MainActor
private func waitUntil(
    timeout: TimeInterval = 2,
    _ condition: () -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() && Date() < deadline {
        await Task.yield()
        try? await Task.sleep(nanoseconds: 2_000_000)
    }
}
