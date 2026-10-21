import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageListStandard

/// 大数据量场景下的消息列表行为测试。
///
/// 这组用例针对 V2（标准模式）消息列表在**长会话 / 高消息量**下的表现。
/// 关注三类问题：
///
/// 1. **正确性** —— 窗口裁剪后是否留下消息缺口；同长度内容修改是否漏刷新。
/// 2. **有界性** —— 内存窗口是否有上限；工具查询是否随窗口线性放大。
/// 3. **可观测性** —— 大数据量下的关键路径耗时是否仍有界（回归护栏）。
///
/// 这些用例全部走**真实 ViewModel + 真实分页服务**，只有存储层被替身化，
/// 以便精确控制「数据库里到底有多少条消息」这一变量。
@MainActor
@Suite("V2 大数据量行为")
struct ListV2LargeDataTests {

    // MARK: - 测试替身

    /// 具备真实游标分页语义的能力替身。
    ///
    /// 与 `StubMessageListMessageCapability` 的区别：后者对「无游标」和
    /// 「有游标」返回同一份固定数据，无法表达「越往回翻越早」的真实语义。
    /// 本替身按 `beforeMessageID` 在全量消息里定位游标并切出对应区间，
    /// 因此能真实复现「翻页 → 窗口裁剪 → 缺口」这类只在长会话出现的缺陷。
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
    /// ## 缺陷背景
    ///
    /// `evictTailIfNeeded` 在用户**不在底部**时裁掉窗口尾部（较新的一段），
    /// 保留头部更早的历史。裁剪后窗口的尾部停在 `m299`，而 `m300...m359`
    /// 这段**既不在窗口里、也不在「更早」方向上**（它们比 `m299` 更新）。
    ///
    /// 随后新消息 `FRESH` 到达并触发尾部刷新：`refreshTail` 拿到的最近一页
    /// 是 `[m360...m399, FRESH]`，与当前窗口**没有重叠**，于是
    /// `refreshTail` 按「用户在翻历史，不要强行覆盖」的规则返回 `nil`，
    /// 新消息进不了窗口；而 `m300...m359` 这一段**永久消失**——
    /// 用户既翻不到它们（翻页只会更早），也看不到它们（不在窗口里）。
    ///
    /// 这是长会话下的**数据丢失级**缺陷：翻过几屏历史后，中间某段消息
    /// 就此从列表中永久消失，且没有任何 UI 提示。
    @Test("翻页裁剪窗口后，新消息到达不得让中间段消息永久消失")
    func tailEvictionDoesNotCreatePermanentGap() async {
        let conversationID = UUID()
        var all = (0..<400).map { userMessage($0, conversationID: conversationID) }
        let capability = PagedMessageCapability(all: all)
        let harness = ViewModelHarness(selected: conversationID, messages: capability)
        await harness.viewModel.activateCurrentConversation()

        // 用户一路向上翻页（不在底部）→ 触发尾部裁剪。
        for _ in 0..<10 {
            _ = await harness.viewModel.loadEarlier(isAtBottom: false)
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
    /// ## 缺陷背景
    ///
    /// `HistoryBuildSignature` 用 `contentLength` 作为内容指纹的一部分，
    /// 目的是「比完整内容字符串便宜」。但等长替换（"AAAA" → "BBBB"）
    /// 会让长度不变，指纹判定为「没变」→ 跳过重建 → 列表继续显示旧文本。
    ///
    /// 这不是纯理论问题：消息内容的重写（流式落库时的最终化、编辑重试、
    /// 错误重试覆盖）都可能产生等长结果。
    @Test("内容被等长替换时历史行必须更新")
    func sameLengthContentEditRebuildsRows() async {
        let conversationID = UUID()
        let original = makeMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "AAAA"
        )
        let manager = StubMessageListMessageCapability(page: [original])
        let harness = ViewModelHarness(selected: conversationID, messages: manager)
        await harness.viewModel.activateCurrentConversation()
        #expect(harness.viewModel.historyRows.first?.content == "AAAA")

        // 等长替换：长度不变，内容变。
        manager.page = [
            makeMessage(
                id: original.id,
                conversationID: conversationID,
                role: .assistant,
                content: "BBBB"
            )
        ]
        _ = await harness.viewModel.refreshTail()

        #expect(
            harness.viewModel.historyRows.first?.content == "BBBB",
            "等长内容替换后历史行仍是旧快照「\(harness.viewModel.historyRows.first?.content ?? "nil")」"
        )
    }

    // MARK: - 有界性：内存窗口必须有上限

    /// 无论用户怎么翻页，内存窗口都不能无上限增长。
    ///
    /// ## 缺陷背景
    ///
    /// `evictTailIfNeeded` 只在 `isAtBottom == false` 时裁剪。用户在**底部**
    /// 反复触发「加载更早消息」（按钮固定在顶部，滚动到顶部点它即可）时，
    /// 窗口会一路涨到整个会话的消息数。
    ///
    /// 实测 2000 条消息全量进入内存：每条都带完整正文与渲染元数据，
    /// `historyRows` 同步重建，`ForEach` 的 diff 集合也随之膨胀。
    @Test("持续翻页时内存窗口不得无上限增长")
    func windowStaysBoundedWhilePaging() async {
        let conversationID = UUID()
        let all = (0..<2000).map { userMessage($0, conversationID: conversationID) }
        let capability = PagedMessageCapability(all: all)
        let harness = ViewModelHarness(selected: conversationID, messages: capability)
        await harness.viewModel.activateCurrentConversation()

        // 在底部连续翻页 50 次（每页 40 条 → 理论可涨到 2000）。
        for _ in 0..<50 {
            _ = await harness.viewModel.loadEarlier(isAtBottom: true)
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
    /// ## 缺陷背景
    ///
    /// `refreshTurnActivitySummaries` 对窗口内**每个 turn** 单独发一次
    /// `toolCalls(for:)` 查询（N+1）。窗口越长，查询次数线性增长。
    /// 每次消息事件（工具结果回写）都会触发一轮全量统计。
    ///
    /// 更关键的是：**这份统计在 V2/V3 的 View 里根本没有被消费** ——
    /// `turnActivitySummaries` 与 `turnActivity(for:)` 在两个插件的
    /// `Views/` 目录下均无引用点。它是纯开销。
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
        let harness = ViewModelHarness(
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
    ///
    /// 这是**回归护栏**：窗口上限（≤300 条）+ 指纹短路共同保证单次重建
    /// 在主线程上是常数级开销。若将来有人放宽窗口上限或去掉指纹短路，
    /// 这条用例会先变红。
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
        let harness = ViewModelHarness(selected: conversationID, messages: capability)
        await harness.viewModel.activateCurrentConversation()

        // 模拟「翻到很长的历史」后的窗口规模。
        for _ in 0..<50 {
            _ = await harness.viewModel.loadEarlier(isAtBottom: true)
        }

        let start = Date()
        harness.viewModel.refreshConversationSettingsIfNeeded()
        let elapsed = Date().timeIntervalSince(start)

        #expect(
            elapsed < 0.5,
            "重建历史行耗时 \(elapsed)s，超出有界预期"
        )
    }

    /// 单个 turn 内大量「只含工具调用」的助手消息应被合并成一行。
    ///
    /// `mergeConsecutiveToolExecutionMessages` 对带 turnID 的消息采用
    /// 「边遍历边回填 `result[index]`」的写法：每收到一条同 turn 消息就把
    /// 整个组合重新构造一次，导致该 turn 的工具调用被反复平铺。
    /// 300 条工具消息时这一段已耗时约 30ms，规模再大即线性恶化。
    @Test("单个 turn 的大量工具消息合并后仍只产生一行")
    func toolOnlyMessagesMergeIntoSingleRow() async {
        let conversationID = UUID()
        let turnID = UUID()
        let messages = (0..<300).map { index in
            makeMessage(
                conversationID: conversationID,
                role: .assistant,
                content: "",
                turnID: turnID,
                toolCalls: [MessageToolCall(id: "call-\(index)", name: "read", arguments: "{}")]
            )
        }
        let rows = MessageListRowBuilder().buildHistory(
            persisted: messages,
            conversationID: conversationID,
            verbosity: .standard
        )

        #expect(rows.count == 1, "300 条同 turn 工具消息应合并为 1 行，实际 \(rows.count) 行")
        #expect(rows[0].toolCalls?.count == 300, "合并后应保留全部 300 个工具调用")
    }
}
