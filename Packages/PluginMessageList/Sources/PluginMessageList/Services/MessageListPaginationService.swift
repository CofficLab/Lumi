import Foundation
import ProviderMessage

/// Message Timeline Pagination Service
///
/// 封装消息时间线的"消息窗口管理"策略（沉淀自旧版同名服务）。
/// 通过 `MessageManaging` 的分页 API 获取窗口数据，存储层可以在查询阶段
/// 限制返回数量，避免长会话每次刷新都物化全部消息。
///
/// 与旧版一致：取数前先**剔除独立的 `.tool` 结果行**（旧版 `messagePage` 默认
/// `includesToolMessages=false`，工具结果消息从不进入 UI 分页窗口；工具信息由
/// 助手消息内联的 toolCalls 呈现）。`MessageListRowBuilder` 再做一层展示兜底。
///
/// 1. **首屏加载** —— 加载最近一页（pageSize 条），并探测是否还有更早消息。
/// 2. **向上翻页** —— 在当前最早一条之前加载更早一页并 prepend。
/// 3. **尾部刷新** —— 重新取最近一页，与当前 `messages` 比对并覆盖尾部重叠区；
///    无重叠且用户正在翻历史时不强行覆盖（避免破坏视觉位置）。
/// 4. **窗口回收** —— 超过 `maxRetainedCount` 时丢弃尾部（较新、远离可视区的），
///    仅在用户**不在底部**时执行（避免裁掉正在流式的尾部）。
@MainActor
struct MessageListPaginationService {
    let pageSize: Int
    let maxRetainedCount: Int

    init(pageSize: Int = 40, maxRetainedCount: Int = 300) {
        self.pageSize = pageSize
        self.maxRetainedCount = maxRetainedCount
    }

    /// 加载首屏（最近一页）+ 是否还有更早消息。
    func loadFirstPage(
        conversationID: UUID,
        messageManager: (any MessageManaging)?
    ) async -> LoadFirstPageResult {
        guard let messageManager else {
            return LoadFirstPageResult(messages: [], hasEarlierMessages: false)
        }
        let page = await messageManager.messagePageAsync(
            for: conversationID,
            limit: pageSize + 1,
            beforeMessageID: nil,
            includesToolMessages: false
        )
        let safePage = Array(page.suffix(pageSize))
        let hasEarlier = page.count > pageSize
        return LoadFirstPageResult(messages: safePage, hasEarlierMessages: hasEarlier)
    }

    /// 向上翻页：在当前最早一条之前加载更早一页。
    ///
    /// 返回 `nil` 表示"无需操作"：无更早消息 / 无当前消息基准 / 更早一页为空。
    func loadEarlier(
        conversationID: UUID,
        messageManager: (any MessageManaging)?,
        currentFirstID: UUID?,
        hasEarlier: Bool
    ) async -> LoadEarlierResult? {
        guard hasEarlier,
              let currentFirstID,
              let messageManager else { return nil }
        let earlier = await messageManager.messagePageAsync(
            for: conversationID,
            limit: pageSize,
            beforeMessageID: currentFirstID,
            includesToolMessages: false
        )
        guard !earlier.isEmpty else { return nil }
        let stillHasEarlier = await messageManager.hasEarlierMessagesAsync(
            for: conversationID,
            beforeMessageID: earlier.first?.id,
            includesToolMessages: false
        )
        return LoadEarlierResult(
            anchorID: currentFirstID,
            earlier: earlier,
            hasEarlierMessages: stillHasEarlier
        )
    }

    /// 尾部刷新：用最近一页覆盖 `messages` 尾部，保留头部更早的历史。
    ///
    /// 返回 `nil` 表示无需操作：缺 `messageManager`；或最近一页为空；或
    /// 与当前 `messages` 完全无重叠且当前有内容（避免破坏用户翻历史的视觉位置）。
    func refreshTail(
        conversationID: UUID,
        messageManager: (any MessageManaging)?,
        current: [Message]
    ) async -> RefreshTailResult? {
        guard let messageManager else { return nil }
        let latestPage = await messageManager.messagePageAsync(
            for: conversationID,
            limit: pageSize,
            beforeMessageID: nil,
            includesToolMessages: false
        )
        guard !latestPage.isEmpty else { return nil }

        let latestIDs = Set(latestPage.map(\.id))
        if let firstOverlapIndex = current.firstIndex(where: { latestIDs.contains($0.id) }) {
            // 找到重叠位置：保留头部更早历史，拼接最新页
            let merged = Array(current[..<firstOverlapIndex]) + latestPage
            return RefreshTailResult(merged: merged, hasEarlierMessages: nil)
        }
        if current.isEmpty {
            // 从无到有：直接把最近一页铺上，并补查 hasEarlier。
            return RefreshTailResult(
                merged: latestPage,
                hasEarlierMessages: await messageManager.hasEarlierMessagesAsync(
                    for: conversationID,
                    beforeMessageID: latestPage.first?.id,
                    includesToolMessages: false
                )
            )
        }
        // 无重叠且当前有内容：用户在翻历史，不要强行覆盖。
        return nil
    }

    /// 窗口回收：超过 `maxRetainedCount` 时丢弃尾部较新消息。
    /// **仅在用户不在底部时执行**（`isAtBottom == false`）——防止裁掉正在流式的尾部。
    func evictTailIfNeeded(
        messages: [Message], isAtBottom: Bool
    ) -> [Message] {
        guard messages.count > maxRetainedCount, !isAtBottom else { return messages }
        let overflow = messages.count - maxRetainedCount
        var trimmed = messages
        trimmed.removeLast(overflow)
        return trimmed
    }
}

// MARK: - Results

/// `loadFirstPage` 的返回结构。
struct LoadFirstPageResult: Sendable {
    let messages: [Message]
    let hasEarlierMessages: Bool
}

/// `loadEarlier` 的返回结构。`anchorID` 是 prepend 前最早一条消息的 id，
/// UI 应在 prepend 后把它钉回视口顶部。
struct LoadEarlierResult: Sendable {
    let anchorID: UUID
    let earlier: [Message]
    let hasEarlierMessages: Bool
}

/// `refreshTail` 的返回结构。`hasEarlierMessages` 仅在"从空到非空"时填值；
/// 其他情况调用方应保留旧值（传 `nil`）。
struct RefreshTailResult: Sendable {
    let merged: [Message]
    let hasEarlierMessages: Bool?
}
