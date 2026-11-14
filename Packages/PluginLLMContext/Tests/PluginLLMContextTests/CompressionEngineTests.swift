import Foundation
import ProviderLLMContext
import ProviderMessage
import Testing

@testable import PluginLLMContext

@MainActor
struct CompressionEngineTests {
    private let conversationID = UUID()

    private func message(
        _ index: Int,
        role: MessageRole = .user,
        content: String? = nil
    ) -> Message {
        Message(
            id: UUID(),
            conversationID: conversationID,
            role: role,
            content: content ?? "消息 \(index)",
            createdAt: Date(timeIntervalSince1970: TimeInterval(index))
        )
    }

    private func history(_ count: Int) -> [Message] {
        (0 ..< count).map { message($0) }
    }

    private func block(
        tier: Int,
        coveredThrough: UUID,
        sourceMessageIDs: [UUID] = [],
        sourceBlockIDs: [UUID] = [],
        createdAt: Date = Date(),
        active: Bool = true,
        summary: String = "摘要"
    ) -> CompressionBlock {
        CompressionBlock(
            conversationID: conversationID,
            tier: tier,
            summary: summary,
            sourceMessageIDs: sourceMessageIDs,
            sourceBlockIDs: sourceBlockIDs,
            coveredThroughMessageID: coveredThrough,
            estimatedTokens: 10,
            createdAt: createdAt,
            active: active
        )
    }

    // MARK: - Ordering & watermark

    @Test("resident 块按内容顺序排列，晚创建的高层块仍排在旧内容处")
    func ordersBlocksByContentNotCreation() {
        let messages = history(10)
        // tier-2 块覆盖 msg0..3，创建时间却晚于覆盖 msg4..7 的 tier-1 块。
        let late = block(
            tier: 2,
            coveredThrough: messages[3].id,
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        let early = block(
            tier: 1,
            coveredThrough: messages[7].id,
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let inactive = block(tier: 1, coveredThrough: messages[9].id, active: false)

        let ordered = CompressionEngine.ordered([early, inactive, late], by: messages)

        #expect(ordered.map(\.id) == [late.id, early.id])
        #expect(CompressionEngine.watermark(ordered) == messages[7].id)
    }

    @Test("没有块时水位为 nil")
    func watermarkNilWithoutBlocks() {
        #expect(CompressionEngine.watermark([]) == nil)
    }

    @Test("最近区间起点保留末尾 recentZone 条")
    func recentZoneStartProtectsTail() {
        #expect(CompressionEngine.recentZoneStart(historyCount: 20, recentZone: 16) == 4)
        #expect(CompressionEngine.recentZoneStart(historyCount: 10, recentZone: 16) == 0)
        #expect(CompressionEngine.recentZoneStart(historyCount: 0, recentZone: 16) == 0)
    }

    // MARK: - Growth-gated tier-1 middle

    @Test("没有块时中间段是最近区间之前的全部历史")
    func tier1MiddleWithoutBlocks() {
        let messages = history(20)
        let middle = CompressionEngine.tier1Middle(
            history: messages,
            orderedBlocks: [],
            recentZone: 16,
            minimumFoldMessages: 1
        )
        #expect(middle?.map(\.id) == messages[0 ..< 4].map(\.id))
    }

    @Test("中间段从水位之后开始，到最近区间之前结束")
    func tier1MiddleAfterWatermark() {
        let messages = history(40)
        let existing = block(tier: 1, coveredThrough: messages[9].id)
        let middle = CompressionEngine.tier1Middle(
            history: messages,
            orderedBlocks: [existing],
            recentZone: 16,
            minimumFoldMessages: 1
        )
        // 水位 msg9，最近区间起点 40-16=24 → 中间段 msg10..23。
        #expect(middle?.map(\.id) == messages[10 ..< 24].map(\.id))
    }

    @Test("增长门控：中间段不足阈值时不折叠")
    func tier1MiddleGrowthGate() {
        let messages = history(40)
        let existing = block(tier: 1, coveredThrough: messages[20].id)
        // 中间段 msg21..23 只有 3 条，低于阈值 16。
        let middle = CompressionEngine.tier1Middle(
            history: messages,
            orderedBlocks: [existing],
            recentZone: 16,
            minimumFoldMessages: 16
        )
        #expect(middle == nil)
    }

    @Test("中间段跳过空内容消息")
    func tier1MiddleSkipsEmptyContent() {
        var messages = history(20)
        messages[1] = message(1, content: "   ")
        let middle = CompressionEngine.tier1Middle(
            history: messages,
            orderedBlocks: [],
            recentZone: 16,
            minimumFoldMessages: 1
        )
        #expect(middle?.map(\.id) == [messages[0].id, messages[2].id, messages[3].id])
    }

    @Test("空正文但带工具声明/配对的消息不得被跳过（#812）")
    func tier1MiddleKeepsEmptyToolTurnMessages() {
        var messages = history(20)
        messages[1] = Message(
            id: messages[1].id,
            conversationID: conversationID,
            role: .assistant,
            content: "",
            createdAt: Date(timeIntervalSince1970: 1),
            toolCalls: [MessageToolCall(id: "call-1", name: "f", arguments: "{}")]
        )
        messages[2] = Message(
            id: messages[2].id,
            conversationID: conversationID,
            role: .tool,
            content: "",
            createdAt: Date(timeIntervalSince1970: 2),
            toolCallID: "call-1"
        )
        let middle = CompressionEngine.tier1Middle(
            history: messages,
            orderedBlocks: [],
            recentZone: 16,
            minimumFoldMessages: 1
        )
        #expect(middle?.map(\.id) == messages[0 ..< 4].map(\.id))
    }

    @Test("末尾 assistant 的工具结果在最近区间时，该 assistant 不进折叠源（#812）")
    func tier1MiddleExcludesAssistantWithResultsInRecentZone() {
        var messages = history(20)
        // zoneStart = 4：assistant 在边界前一条，结果落在最近区间里。
        messages[3] = Message(
            id: messages[3].id,
            conversationID: conversationID,
            role: .assistant,
            content: "",
            createdAt: Date(timeIntervalSince1970: 3),
            toolCalls: [MessageToolCall(id: "call-1", name: "f", arguments: "{}")]
        )
        messages[4] = Message(
            id: messages[4].id,
            conversationID: conversationID,
            role: .tool,
            content: "ok",
            createdAt: Date(timeIntervalSince1970: 4),
            toolCallID: "call-1"
        )
        let middle = CompressionEngine.tier1Middle(
            history: messages,
            orderedBlocks: [],
            recentZone: 16,
            minimumFoldMessages: 1
        )
        #expect(middle?.map(\.id) == messages[0 ..< 3].map(\.id))
    }

    @Test("工具回合完整落在中间段时保持完整折叠（#812）")
    func tier1MiddleKeepsCompleteToolTurn() {
        var messages = history(20)
        messages[2] = Message(
            id: messages[2].id,
            conversationID: conversationID,
            role: .assistant,
            content: "",
            createdAt: Date(timeIntervalSince1970: 2),
            toolCalls: [MessageToolCall(id: "call-1", name: "f", arguments: "{}")]
        )
        messages[3] = Message(
            id: messages[3].id,
            conversationID: conversationID,
            role: .tool,
            content: "ok",
            createdAt: Date(timeIntervalSince1970: 3),
            toolCallID: "call-1"
        )
        let middle = CompressionEngine.tier1Middle(
            history: messages,
            orderedBlocks: [],
            recentZone: 16,
            minimumFoldMessages: 1
        )
        #expect(middle?.map(\.id) == messages[0 ..< 4].map(\.id))
    }

    @Test("水位消息已不在历史中时放弃折叠")
    func tier1MiddleMissingWatermark() {
        let messages = history(20)
        let orphan = block(tier: 1, coveredThrough: UUID())
        let middle = CompressionEngine.tier1Middle(
            history: messages,
            orderedBlocks: [orphan],
            recentZone: 16,
            minimumFoldMessages: 1
        )
        #expect(middle == nil)
    }

    // MARK: - Higher-tier fold batch

    @Test("某层攒够 fanout 时取最旧一批折叠")
    func foldBatchTakesOldest() {
        let messages = history(20)
        let blocks = (0 ..< 5).map { index in
            block(tier: 1, coveredThrough: messages[index * 2].id)
        }
        let ordered = CompressionEngine.ordered(blocks, by: messages)
        let batch = CompressionEngine.foldBatch(ordered, tier: 1, fanout: 4)
        #expect(batch?.map(\.id) == ordered.prefix(4).map(\.id))
    }

    @Test("未攒够 fanout 时不折叠")
    func foldBatchBelowFanout() {
        let messages = history(20)
        let blocks = (0 ..< 3).map { index in
            block(tier: 1, coveredThrough: messages[index].id)
        }
        let ordered = CompressionEngine.ordered(blocks, by: messages)
        #expect(CompressionEngine.foldBatch(ordered, tier: 1, fanout: 4) == nil)
    }

    @Test("折叠批次只取指定层，且忽略停用块")
    func foldBatchOnlySameTierActive() {
        let messages = history(20)
        let tier1 = (0 ..< 4).map { index in
            block(tier: 1, coveredThrough: messages[index].id)
        }
        let tier2 = block(tier: 2, coveredThrough: messages[10].id)
        let inactive = block(tier: 1, coveredThrough: messages[15].id, active: false)
        let ordered = CompressionEngine.ordered(tier1 + [tier2, inactive], by: messages)
        let batch = CompressionEngine.foldBatch(ordered, tier: 1, fanout: 4)
        #expect(batch?.count == 4)
        #expect(batch?.allSatisfy { $0.tier == 1 } == true)
    }

    // MARK: - Lineage

    @Test("tier-1 血缘直接返回源消息 ID")
    func lineageTier1() {
        let messages = history(5)
        let ids = messages.map(\.id)
        let b = block(tier: 1, coveredThrough: ids[4], sourceMessageIDs: ids)
        #expect(CompressionEngine.sourceMessageIDs(of: b.id, in: [b]) == ids)
    }

    @Test("tier-2 血缘逐层回溯到原始消息并保持顺序去重")
    func lineageTier2Transitive() {
        let messages = history(6)
        let ids = messages.map(\.id)
        let lower1 = block(tier: 1, coveredThrough: ids[2], sourceMessageIDs: Array(ids[0 ... 2]))
        let lower2 = block(tier: 1, coveredThrough: ids[5], sourceMessageIDs: Array(ids[3 ... 5]))
        let upper = block(
            tier: 2,
            coveredThrough: ids[5],
            sourceBlockIDs: [lower1.id, lower2.id]
        )
        let resolved = CompressionEngine.sourceMessageIDs(
            of: upper.id,
            in: [upper, lower1, lower2]
        )
        #expect(resolved == ids)
    }

    @Test("血缘环不会导致无限递归")
    func lineageCycleSafe() {
        let a = block(tier: 2, coveredThrough: UUID(), sourceBlockIDs: [])
        let b = block(tier: 2, coveredThrough: UUID(), sourceBlockIDs: [])
        // 手工构造环：a→b→a。用可变副本重建。
        var cyclicA = a
        var cyclicB = b
        cyclicA = CompressionBlock(
            id: a.id, conversationID: conversationID, tier: 2, summary: "a",
            sourceBlockIDs: [b.id], coveredThroughMessageID: a.coveredThroughMessageID,
            estimatedTokens: 1
        )
        cyclicB = CompressionBlock(
            id: b.id, conversationID: conversationID, tier: 2, summary: "b",
            sourceBlockIDs: [a.id], coveredThroughMessageID: b.coveredThroughMessageID,
            estimatedTokens: 1
        )
        #expect(CompressionEngine.sourceMessageIDs(of: cyclicA.id, in: [cyclicA, cyclicB]).isEmpty)
    }

    @Test("缺失块 ID 的血缘静默跳过")
    func lineageMissingBlock() {
        let b = block(tier: 2, coveredThrough: UUID(), sourceBlockIDs: [UUID()])
        #expect(CompressionEngine.sourceMessageIDs(of: b.id, in: [b]).isEmpty)
        #expect(CompressionEngine.sourceMessageIDs(of: UUID(), in: [b]).isEmpty)
    }

    // MARK: - Prefix-preserving render

    @Test("system 前缀只取最前面连续的 system 消息")
    func systemPrefixLeadingRunOnly() {
        var messages = history(6)
        messages[0] = message(0, role: .system, content: "系统提示")
        messages[1] = message(1, role: .system, content: "第二条系统")
        messages[3] = message(3, role: .system, content: "中间系统")
        let prefix = CompressionEngine.systemPrefix(messages)
        #expect(prefix.map(\.id) == [messages[0].id, messages[1].id])
    }

    @Test("块消息内容与元数据完全由块决定")
    func blockMessageIsImmutable() {
        let b = block(tier: 2, coveredThrough: UUID(), summary: "固定摘要")
        let rendered = CompressionEngine.blockMessage(b, conversationID: conversationID)
        #expect(rendered.role == .system)
        #expect(rendered.content.contains("固定摘要"))
        #expect(rendered.content.contains("tier 2"))
        #expect(rendered.metadata[CompressionEngine.summaryMetadataKey] == "summary")
        #expect(rendered.metadata[CompressionEngine.blockIDMetadataKey] == b.id.uuidString)
        #expect(rendered.metadata[CompressionEngine.tierMetadataKey] == "2")
    }

    @Test("追加新块不改写已渲染前缀的字节（前缀缓存命中）")
    func appendingBlockPreservesPrefixBytes() {
        let messages = history(20)
        let first = block(tier: 1, coveredThrough: messages[4].id, summary: "第一段")
        let prefixBefore = CompressionEngine.renderPrefix(
            history: messages,
            orderedBlocks: [first],
            conversationID: conversationID
        )

        // 追加一个覆盖更晚内容的新块。
        let second = block(tier: 1, coveredThrough: messages[9].id, summary: "第二段")
        let ordered = CompressionEngine.ordered([first, second], by: messages)
        let prefixAfter = CompressionEngine.renderPrefix(
            history: messages,
            orderedBlocks: ordered,
            conversationID: conversationID
        )

        #expect(prefixAfter.count == prefixBefore.count + 1)
        #expect(Array(prefixAfter.prefix(prefixBefore.count)) == prefixBefore)
    }

    @Test("折叠停用旧块后，前缀以高层块替换被折叠范围")
    func foldingDeactivatesLowerBlocks() {
        let messages = history(20)
        let lower1 = block(tier: 1, coveredThrough: messages[2].id, summary: "L1")
        let lower2 = block(tier: 1, coveredThrough: messages[5].id, summary: "L2")
        let upper = block(
            tier: 2,
            coveredThrough: messages[5].id,
            sourceBlockIDs: [lower1.id, lower2.id],
            summary: "U"
        )
        // 折叠后：低层块停用，仅高层块 active。
        var deactivated1 = lower1
        var deactivated2 = lower2
        deactivated1.active = false
        deactivated2.active = false
        let ordered = CompressionEngine.ordered([deactivated1, deactivated2, upper], by: messages)
        #expect(ordered.map(\.id) == [upper.id])
        let prefix = CompressionEngine.renderPrefix(
            history: messages,
            orderedBlocks: ordered,
            conversationID: conversationID
        )
        #expect(prefix.contains { $0.content.contains("U") })
        #expect(!prefix.contains { $0.content.contains("L1") })
    }
}