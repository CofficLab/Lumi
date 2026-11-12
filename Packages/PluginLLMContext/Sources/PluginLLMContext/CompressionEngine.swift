import Foundation
import ProviderLLMContext
import ProviderMessage

/// fold-once 分层压缩的纯算法层（#1160）。
///
/// 这里只做与 LLM / 持久化无关的选择与组装：块的内容排序、覆盖水位、血缘回溯、
/// 增长门控的 tier-1 折叠源、高层折叠批次，以及保前缀的渲染组装。预算裁剪、
/// 工具配对、校准降级等不变量仍由 `LLMContextProvider` 负责。
enum CompressionEngine {
    /// 渲染块消息时附带的元数据键，沿用旧摘要标记以兼容时间线与既有断言。
    static let summaryMetadataKey = "llmContext"
    static let summaryMetadataValue = "summary"
    static let blockIDMetadataKey = "llmContextBlockID"
    static let tierMetadataKey = "llmContextTier"

    /// 只取 active 块，并按内容（时间）顺序排列。
    ///
    /// 内容顺序以 `coveredThroughMessageID` 在历史中的位置为准：tier-2 块虽然
    /// 创建得更晚，却代表更旧的内容，必须排在它所折叠的范围处，而不是末尾。
    /// 找不到水位消息时（历史被裁剪）退化为 createdAt，再退化为 id，保证全序稳定。
    static func ordered(_ blocks: [CompressionBlock], by history: [Message]) -> [CompressionBlock] {
        var position: [UUID: Int] = [:]
        for (index, message) in history.enumerated() {
            position[message.id] = index
        }
        return blocks.filter(\.active).sorted { lhs, rhs in
            let lhsPosition = position[lhs.coveredThroughMessageID]
            let rhsPosition = position[rhs.coveredThroughMessageID]
            if let lhsPosition, let rhsPosition, lhsPosition != rhsPosition {
                return lhsPosition < rhsPosition
            }
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    /// 当前 resident 块覆盖到的最后一条原始消息 ID；没有块时为 nil。
    static func watermark(_ orderedBlocks: [CompressionBlock]) -> UUID? {
        orderedBlocks.last?.coveredThroughMessageID
    }

    /// 逐字保留的最近区间起点：历史末尾 `recentZone` 条不做折叠。
    static func recentZoneStart(historyCount: Int, recentZone: Int) -> Int {
        max(historyCount - max(recentZone, 0), 0)
    }

    /// tier-1 折叠源：水位之后、最近区间之前的「未覆盖中间段」。
    ///
    /// 增长门控：中间段不足 `minimumFoldMessages` 条时返回 nil，避免每个回合
    /// 都为几条新消息重新压缩（#1160 增长门控、增量触发）。空内容消息不携带
    /// 信息，直接跳过。返回的数组按时间升序，调用方再按摘要预算裁剪。
    static func tier1Middle(
        history: [Message],
        orderedBlocks: [CompressionBlock],
        recentZone: Int,
        minimumFoldMessages: Int
    ) -> [Message]? {
        let zoneStart = recentZoneStart(historyCount: history.count, recentZone: recentZone)
        let startIndex: Int
        if let watermark = watermark(orderedBlocks),
           let watermarkIndex = history.firstIndex(where: { $0.id == watermark }) {
            startIndex = watermarkIndex + 1
        } else if orderedBlocks.isEmpty {
            startIndex = 0
        } else {
            // 有块但水位消息已不在历史里：无法安全确定中间段，放弃本次折叠。
            return nil
        }
        guard startIndex < zoneStart else { return nil }
        let middle = history[startIndex ..< zoneStart].filter {
            !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        // 增长门控只约束「已有块之后的增量」：首次折叠（无块）只要中间段非空
        // 就执行，否则短会话永远产不出第一份摘要；已有块时不足阈值则不重压，
        // 避免每回合为几条新消息重新折叠（#1160 增长门控、增量触发）。
        let threshold = orderedBlocks.isEmpty ? 1 : max(minimumFoldMessages, 1)
        guard middle.count >= threshold else { return nil }
        return middle
    }

    /// 高层折叠批次：某层 active 块数量达到 `fanout` 时，取最旧的一批折叠成上一层。
    ///
    /// 只折叠块、绝不重新折叠原始历史（fold-once）。返回 nil 表示该层尚未攒够。
    static func foldBatch(
        _ orderedBlocks: [CompressionBlock],
        tier: Int,
        fanout: Int
    ) -> [CompressionBlock]? {
        guard fanout >= 2 else { return nil }
        let sameTier = orderedBlocks.filter { $0.tier == tier }
        guard sameTier.count >= fanout else { return nil }
        return Array(sameTier.prefix(fanout))
    }

    /// 一个块逐层回溯到的全部原始消息 ID（按内容升序、去重）。
    ///
    /// tier-1 直接返回 `sourceMessageIDs`；tier ≥ 2 沿 `sourceBlockIDs` 递归。
    /// 用 visited 防御血缘环；缺失的块 ID 静默跳过（迁移块可能没有完整血缘）。
    static func sourceMessageIDs(of blockID: UUID, in blocks: [CompressionBlock]) -> [UUID] {
        let byID = Dictionary(blocks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var result: [UUID] = []
        var seenMessages: Set<UUID> = []
        var visitedBlocks: Set<UUID> = []

        func walk(_ id: UUID) {
            guard visitedBlocks.insert(id).inserted, let block = byID[id] else { return }
            if block.tier <= 1 {
                for messageID in block.sourceMessageIDs where seenMessages.insert(messageID).inserted {
                    result.append(messageID)
                }
                return
            }
            for childID in block.sourceBlockIDs {
                walk(childID)
            }
        }

        walk(blockID)
        return result
    }

    /// 历史最前面连续的 system 消息（系统提示），跨回合字节稳定。
    static func systemPrefix(_ history: [Message]) -> [Message] {
        Array(history.prefix(while: { $0.role == .system }))
    }

    /// 把一个不可变块渲染成 system 消息。
    ///
    /// id、createdAt、内容与元数据完全由块决定，因此同一块在多次渲染中产出
    /// 字节一致的消息——这是前缀缓存命中的关键。渲染消息是临时的（只发给
    /// provider，不落库），用块 id 作消息 id 不会与真实消息冲突。
    static func blockMessage(_ block: CompressionBlock, conversationID: UUID) -> Message {
        Message(
            id: block.id,
            conversationID: conversationID,
            role: .system,
            content: "Conversation summary (tier \(block.tier), older messages):\n\n\(block.summary)",
            createdAt: block.createdAt,
            metadata: [
                summaryMetadataKey: summaryMetadataValue,
                blockIDMetadataKey: block.id.uuidString,
                tierMetadataKey: "\(block.tier)",
            ]
        )
    }

    /// 保前缀组装的前半段：稳定 system 前缀 + 按内容序的不可变块消息。
    ///
    /// 只追加新块、停用被折叠的旧块，不改写已渲染的字节；逐字尾部由调用方
    /// 按预算裁剪后接在后面。
    static func renderPrefix(
        history: [Message],
        orderedBlocks: [CompressionBlock],
        conversationID: UUID
    ) -> [Message] {
        systemPrefix(history) + orderedBlocks.map { blockMessage($0, conversationID: conversationID) }
    }
}