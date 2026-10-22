import Foundation
import ProviderConversationState
import ProviderMessage
import Testing
@testable import PluginMessageListDetailed

/// 大数据量场景下的消息列表行为测试（V3 / detailed 模式）。
///
/// 这组用例针对 V3 消息列表在**长会话 / 高消息量**下的表现，与 V2
/// （standard 模式）的同名用例一一对应：三个插件互不依赖、各自一份实现，
/// 缺陷必须同步修复，改一处须同步另两处。
///
/// 关注三类问题：
///
/// 1. **正确性** —— 窗口裁剪后是否留下消息缺口；同长度内容修改是否漏刷新。
/// 2. **有界性** —— 内存窗口是否有上限；工具查询是否随窗口线性放大。
/// 3. **可观测性** —— 大数据量下的关键路径耗时是否仍有界（回归护栏）。
@MainActor
@Suite("V3 大数据量行为")
struct ListV3LargeDataTests {

    // MARK: - 测试替身

    /// 具备真实游标分页语义的能力替身。
    ///
    /// 按 `beforeMessageID` 在全量消息里定位游标并切出对应区间，因此能真实
    /// 复现「翻页 → 窗口裁剪 → 缺口」这类只在长会话出现的缺陷。
    final class PagedMessageCapability: MessageListMessageCapability {
        /// 全量消息（按时间升序）。
        var all: [Message] = []
        /// 记录每页请求的游标，便于断言「翻页确实推进了」。
        private(set) var requestedCursors: [UUID?] = []

        init(all: [Message]) { self.all = all }

        func messagesSnapshot(in conversationID: UUID) async -> [Message] { all }

        func messagePageAsync(
            for conversationID: UUID,
            limit: Int,
            beforeMessageID: UUID?,
            includesToolMessages: Bool
        ) async -> [Message] {
            requestedCursors.append(beforeMessageID)
            let filtered = all.filter { includesToolMessages || $0.role != .tool }
            guard let beforeMessageID else { return Array(filtered.suffix(limit)) }
            guard let index = filtered.firstIndex(where: { $0.id == beforeMessageID }) else { return [] }
            return Array(filtered[max(0, index - limit)..<index])
        }

        func hasEarlierMessagesAsync(
            for conversationID: UUID,
            beforeMessageID: UUID?,
            includesToolMessages: Bool
        ) async -> Bool {
            let filtered = all.filter { includesToolMessages || $0.role != .tool }
            guard let beforeMessageID else { return filtered.count > 10 }
            guard let index = filtered.firstIndex(where: { $0.id == beforeMessageID }) else { return false }
            return index > 0
        }
    }

    /// 构造一条按时间递增的 user 消息。
    private func userMessage(
        _ index: Int,
        conversationID: UUID,
        base: TimeInterval = 1_700_000_000
    ) -> Message {
        makeMessage(
            conversationID: conversationID,
            role: .user,
            content: "m\(index)",
            createdAt: Date(timeIntervalSince1970: base + Double(index))
        )
    }

    // MARK: - 正确性：窗口裁剪不得留下永久缺口

    /// 向上翻页触发尾部裁剪后，新消息到达必须能重新接上被裁掉的那一段。
    ///
    /// `evictTailIfNeeded` 会裁掉窗口尾部（较新的一段），保留头部更早的历史。
    /// 裁剪后窗口的尾部停在 `m299`，而 `m300...m359` 这段**既不在窗口里、
    /// 也不在「更早」方向上**（它们比 `m299` 更新）。
    ///
    /// 随后新消息 `FRESH` 到达并触发尾部刷新：`refreshTail` 拿到的最近一页
    /// 与当前窗口**没有重叠**，若按「用户在翻历史，不要强行覆盖」的规则返回
    /// `nil`，新消息进不了窗口；而 `m300...m359` 这一段**永久消失**——
    /// 用户既翻不到它们（翻页只会更早），也看不到它们（不在窗口里）。
    ///
    /// 这是长会话下的**数据丢失级**缺陷。
    @Test("翻页裁剪窗口后，新消息到达不得让中间段消息永久消失")
    func tailEvictionDoesNotCreatePermanentGap() async {
        let conversationID = UUID()
        var all = (0..<400).map { userMessage($0, conversationID: conversationID) }
        let capability = PagedMessageCapability(all: all)
        let harness = makeHarness(selected: conversationID, messages: capability)
        await harness.viewModel.activateCurrentConversation()

        // 用户一路向上翻页（不在底部）→ 触发尾部裁剪。
        for _ in 0..<10 {
            _ = await harness.viewModel.loadEarlier()
        }

        let afterPaging = harness.viewModel.persistedMessages
        #expect(
            afterPaging.count <= 300,
            "窗口应被裁剪到 maxRetainedCount(300) 以内，实际 \(afterPaging.count)"
        )

        // 新消息到达（流式落库 / 发送完成）。
        let fresh = makeMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "FRESH",
            createdAt: Date(timeIntervalSince1970: 1_700_000_500)
        )
        all.append(fresh)
        capability.all = all
        harness.viewModel.handleMessageChange(.inserted(fresh, conversationID: conversationID))
        try? await Task.sleep(nanoseconds: 60_000_000)
        _ = await harness.viewModel.refreshTail()

        let windowContents = Set(harness.viewModel.persistedMessages.map(\.content))
        let missing = (0..<400).map { "m\($0)" }.filter { !windowContents.contains($0) }

        #expect(
            missing.isEmpty,
            "以下消息从窗口中永久消失（既翻不到也不显示）：\(missing.prefix(10))…共 \(missing.count) 条"
        )
        #expect(
            windowContents.contains("FRESH"),
            "新消息未能进入窗口"
        )
    }

    /// 内容被**等长替换**时，历史行必须跟着更新。
    ///
    /// `HistoryBuildSignature` 用 `contentLength` 作为内容指纹的一部分，
    /// 等长替换（"AAAA" → "BBBB"）会让长度不变，指纹判定为「没变」→
    /// 跳过重建 → 列表继续显示旧文本。
    @Test("内容被等长替换时历史行必须更新")
    func sameLengthContentEditRebuildsRows() async {
        let conversationID = UUID()
        let original = makeMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "AAAA"
        )
        let manager = StubMessageListMessageCapability(page: [original])
        let harness = makeHarness(selected: conversationID, messages: manager)
        await harness.viewModel.activateCurrentConversation()
        #expect(harness.viewModel.historyRows.first?.content == "AAAA")

        // 等长替换：长度不变，内容变。
        manager.setPage([
            makeMessage(
                id: original.id,
                conversationID: conversationID,
                role: .assistant,
                content: "BBBB"
            )
        ])
        _ = await harness.viewModel.refreshTail()

        #expect(
            harness.viewModel.historyRows.first?.content == "BBBB",
            "等长内容替换后历史行仍是旧快照「\(harness.viewModel.historyRows.first?.content ?? "nil")」"
        )
    }

    // MARK: - 有界性：内存窗口必须有上限

    /// 无论用户怎么翻页，内存窗口都不能无上限增长。
    ///
    /// `evictTailIfNeeded` 只在 `isAtBottom == false` 时裁剪时，用户在**底部**
    /// 反复触发「加载更早消息」时，窗口会一路涨到整个会话的消息数。
    @Test("持续翻页时内存窗口不得无上限增长")
    func windowStaysBoundedWhilePaging() async {
        let conversationID = UUID()
        let all = (0..<2000).map { userMessage($0, conversationID: conversationID) }
        let capability = PagedMessageCapability(all: all)
        let harness = makeHarness(selected: conversationID, messages: capability)
        await harness.viewModel.activateCurrentConversation()

        // 在底部连续翻页 50 次（每页 40 条 → 理论可涨到 2000）。
        for _ in 0..<50 {
            _ = await harness.viewModel.loadEarlier()
        }

        #expect(
            harness.viewModel.persistedMessages.count <= 300,
            "在底部连续翻页后窗口涨到 \(harness.viewModel.persistedMessages.count) 条，窗口上限失效"
        )
        #expect(
            harness.viewModel.historyRows.count <= 300,
            "历史行涨到 \(harness.viewModel.historyRows.count) 条，窗口上限失效"
        )
    }

    /// 工具调用统计的查询次数不应随窗口线性放大。
    ///
    /// `refreshTurnActivitySummaries` 对窗口内**每个 turn** 单独发一次
    /// `toolCalls(for:)` 查询（N+1）。窗口越长，查询次数线性增长。
    @Test("工具调用统计不应随窗口内 turn 数线性放大")
    func toolCallQueriesDoNotScaleWithTurnCount() async {
        let conversationID = UUID()
        var all: [Message] = []
        for index in 0..<300 {
            all.append(makeMessage(
                conversationID: conversationID,
                role: .assistant,
                content: "a\(index)",
                createdAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(index)),
                turnID: UUID()
            ))
        }
        let toolManager = StubToolManagerCapability()
        let capability = PagedMessageCapability(all: all)
        let harness = makeHarness(
            selected: conversationID,
            messages: capability,
            toolManager: toolManager
        )
        await harness.viewModel.activateCurrentConversation()
        #expect(harness.viewModel.persistedMessages.count == 40)

        let baseline = toolManager.toolCallsRequestCount
        // 追加一条新消息，让尾部刷新**真的**检测到窗口变化。
        let fresh = makeMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "NEW",
            createdAt: Date(timeIntervalSince1970: 1_700_001_000)
        )
        all.append(fresh)
        capability.all = all
        _ = await harness.viewModel.refreshTail()
        let queries = toolManager.toolCallsRequestCount - baseline

        #expect(
            queries <= 1,
            "一次尾部刷新发起了 \(queries) 次工具查询（窗口内 40 个 turn），应为批量或零次"
        )
    }

    // MARK: - 可观测性：关键路径耗时有界

    /// 大数据量下重建历史行的耗时应保持有界（毫秒级）。
    @Test("大窗口下重建历史行的耗时应保持有界")
    func rebuildHistoryRowsStaysFastAtScale() async {
        let conversationID = UUID()
        let all = (0..<2000).map { index in
            makeMessage(
                conversationID: conversationID,
                role: .assistant,
                content: "第 \(index) 条消息内容 " + String(repeating: "内容", count: 50),
                createdAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(index))
            )
        }
        let capability = PagedMessageCapability(all: all)
        let harness = makeHarness(selected: conversationID, messages: capability)
        await harness.viewModel.activateCurrentConversation()

        // 模拟「翻到很长的历史」后的窗口规模。
        for _ in 0..<50 {
            _ = await harness.viewModel.loadEarlier()
        }

        let start = Date()
        harness.viewModel.refreshConversationSettingsIfNeeded()
        let elapsed = Date().timeIntervalSince(start)

        #expect(
            elapsed < 0.5,
            "重建历史行耗时 \(elapsed)s，超出有界预期"
        )
    }

    // MARK: - 装配

    /// 构造一条测试消息。
    private func makeMessage(
        id: UUID = UUID(),
        conversationID: UUID,
        role: MessageRole,
        content: String,
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

    /// 组装被测 ViewModel 所需的最小依赖集。
    ///
    /// 与 `ListV3ViewModelTests` 里的 `Harness` 分开：那份把消息能力写死成
    /// `StubMessageListMessageCapability`，无法表达「按游标翻页」的真实语义。
    @MainActor
    private func makeHarness(
        selected: UUID?,
        messages: any MessageListMessageCapability,
        toolManager: StubToolManagerCapability = StubToolManagerCapability()
    ) -> (viewModel: ListV3ViewModel, toolManager: StubToolManagerCapability) {
        let conversations = StubConversationCapability(selectedConversationID: selected)
        let conversationState = StubConversationStateCapability(
            snapshot: ConversationStateSnapshot(
                conversationID: selected ?? UUID(),
                activity: nil
            )
        )
        let streaming = StubStreamingCapability()
        let viewModel = ListV3ViewModel(
            services: MessageListServices(
                conversations: conversations,
                conversationState: conversationState,
                developerModeState: DeveloperModeStateViewModel(),
                messages: messages,
                rendering: nil,
                streaming: streaming,
                toolManager: toolManager,
                agentTurn: StubAgentLoopCapability(),
                promptSuggestions: nil,
                promptSuggestionExecutor: nil,
                project: nil,
                toolbar: nil,
                chat: nil
            ),
            pagination: MessageListPaginationService(pageSize: 40, maxRetainedCount: 300),
            streamingDisplayEnabled: false
        )
        return (viewModel, toolManager)
    }
}
