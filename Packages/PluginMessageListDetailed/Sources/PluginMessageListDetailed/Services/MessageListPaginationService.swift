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
///    窗口回收裁掉的空档会被逐页回填，避免中间段消息永久消失。
/// 4. **窗口回收** —— 超过 `maxRetainedCount` 时丢弃尾部（较新、远离可视区的），
///    裁掉的部分由尾部刷新回填，不会丢失。
@MainActor
struct MessageListPaginationService {
    let pageSize: Int
    let maxRetainedCount: Int

    /// 回填空档时最多往前取几页。空档长度取决于用户向上翻了多少页，
    /// 上限用于兜住极端长会话，避免尾部刷新退化成无界扫描。
    private static let maxBackfillRounds = 10

    init(pageSize: Int = 40, maxRetainedCount: Int = 300) {
        self.pageSize = pageSize
        self.maxRetainedCount = maxRetainedCount
    }

    /// 加载首屏（最近一页）+ 是否还有更早消息。
    func loadFirstPage(
        conversationID: UUID,
        messageManager: (any MessageListMessageCapability)?
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
        messageManager: (any MessageListMessageCapability)?,
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
    /// ## 为什么需要回填空档
    ///
    /// 窗口回收（`evictTailIfNeeded`）会丢掉窗口尾部较新的一段。用户继续向上翻页时，
    /// 那一段既不在窗口里、也不在「更早」方向上 —— 它落在**窗口尾部之后**，
    /// 只有一次尾部刷新能把它带回来。
    ///
    /// 若尾部刷新只拼接「最近一页」，窗口尾部与最近一页之间的**空档**就会被永久留下：
    /// 那一段既翻不到（翻页只会更早）、也看不到（不在窗口里）—— 数据丢失级缺陷。
    /// 因此这里在发现空档时**逐页回填**直到接上窗口尾部。
    ///
    /// 回填找不到消息（说明本来就没有空档，只是窗口整体落后于最近一页）时，
    /// 仍按「用户在翻历史，不要强行覆盖」处理，返回 `nil`。
    ///
    /// - Returns: `nil` 表示无需操作：缺 `messageManager`；或最近一页为空；
    ///   或窗口与最近一页之间没有空档且没有重叠。
    func refreshTail(
        conversationID: UUID,
        messageManager: (any MessageListMessageCapability)?,
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

        guard !current.isEmpty else {
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

        let pageHead = latestPage[0]
        let pageIDs = Set(latestPage.map(\.id))

        // 情形一：最近一页的头部就在窗口里 —— 窗口尾部被这一页整段覆盖，没有空档。
        //   按 **id** 判定重叠，不用时间序：同一条消息被更新后，落库版本可能带着
        //   与内存版本不同的时间戳，按时间序判定会误判成「有空档」。
        if let headIndex = current.firstIndex(where: { $0.id == pageHead.id }) {
            let merged = Array(current[..<headIndex]) + latestPage
            return RefreshTailResult(merged: merged, hasEarlierMessages: nil)
        }

        // 情形二：窗口与最近一页之间可能有空档（窗口回收裁掉的那一段）。
        //
        //   窗口整体都不比页头更早时，窗口缺的是「更早」方向上的消息 —— 翻页就能
        //   拿到，不该强行覆盖（那会打断用户翻历史）。
        guard let oldest = current.first, Self.isOrderedBefore(oldest, pageHead) else { return nil }

        // 空档的边界是「窗口里比页头更早的最后一个元素」。比页头更新的窗口元素
        // （本地刚插入、还没落库的消息）不参与边界判定，否则空档会被算成空的。
        guard let windowTail = current.last(where: { Self.isOrderedBefore($0, pageHead) }) else {
            return nil
        }

        let currentIDs = Set(current.map(\.id))
        let gap = await backfillGap(
            conversationID: conversationID,
            messageManager: messageManager,
            windowTail: windowTail,
            pageHead: pageHead,
            currentIDs: currentIDs,
            pageIDs: pageIDs
        )
        guard !gap.isEmpty else { return nil }

        // 组装（按时间升序）：
        //   窗口里比页头更早的部分 → 回填出的空档 → 最近一页 →
        //   窗口里比最近一页还更新、且不在这页里的消息（本地插入、尚未落库）。
        let splitIndex = current.firstIndex { !Self.isOrderedBefore($0, pageHead) } ?? current.count
        let pageTail = latestPage[latestPage.count - 1]
        let newerThanPageTail = current[splitIndex...].filter {
            !pageIDs.contains($0.id) && Self.isOrderedBefore(pageTail, $0)
        }
        let merged = Array(current[..<splitIndex]) + gap + latestPage + newerThanPageTail
        return RefreshTailResult(merged: merged, hasEarlierMessages: nil)
    }

    /// 回填窗口尾部与最近一页之间的空档。
    ///
    /// 从最近一页的头部往前逐页取，直到取到已经在窗口里的消息（空档到此闭合）
    /// 或绕回最近一页。
    ///
    /// - Returns: 空档内的消息（按时间升序）；没有空档时返回空数组。
    private func backfillGap(
        conversationID: UUID,
        messageManager: any MessageListMessageCapability,
        windowTail: Message,
        pageHead: Message,
        currentIDs: Set<UUID>,
        pageIDs: Set<UUID>
    ) async -> [Message] {
        var cursor = pageHead.id
        var collected: [Message] = []

        for _ in 0..<Self.maxBackfillRounds {
            let page = await messageManager.messagePageAsync(
                for: conversationID,
                limit: pageSize,
                beforeMessageID: cursor,
                includesToolMessages: false
            )
            guard !page.isEmpty else { break }
            collected.append(contentsOf: page)

            // 已经接上窗口（或绕回最近一页）→ 空档到此为止。
            if page.contains(where: { currentIDs.contains($0.id) || pageIDs.contains($0.id) }) {
                break
            }
            guard let oldest = page.first else { break }
            cursor = oldest.id
        }

        // 只保留空档区间里的消息：比窗口尾部更新、比页头更早，且既不在窗口里、
        // 也不在最近一页里。
        //
        // 「比窗口尾部更新」这一条保证合并后的窗口仍然按时间升序 —— 回填的页
        // 可能跨过窗口尾部的位置，把更早的消息一起带回来。
        var seen = Set<UUID>()
        return collected
            .filter {
                !currentIDs.contains($0.id) && !pageIDs.contains($0.id)
                    && Self.isOrderedBefore(windowTail, $0)
                    && Self.isOrderedBefore($0, pageHead)
            }
            .filter { seen.insert($0.id).inserted }
            .sorted(by: Self.isOrderedBefore)
    }

    /// 消息的时间序比较：先比创建时间，再比 id（与存储层 `ORDER BY` 一致）。
    private static func isOrderedBefore(_ lhs: Message, _ rhs: Message) -> Bool {
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    /// 窗口回收：超过 `maxRetainedCount` 时丢弃尾部较新消息。
    ///
    /// ## 为什么不再区分「是否在底部」
    ///
    /// 旧实现只在用户**离开底部**时回收，理由是「别裁掉用户正在看的内容」。
    /// 但这让窗口上限形同虚设：用户在底部反复触发「加载更早消息」时，整个
    /// 会话会被拉进内存（实测 2000 条），`historyRows` 同步重建，`ForEach`
    /// 的 diff 集合也随之膨胀。
    ///
    /// 裁尾部在这两种场景下都可接受：
    ///
    /// - 用户离开底部时，尾部在视口之外，裁掉不影响当前阅读。
    /// - 用户在底部时，裁掉的尾部会在下一次尾部刷新时被回填（见 `refreshTail`
    ///   的空档回填），不会永久丢失。
    ///
    /// 之所以裁**尾部**而不是头部：头部正是「加载更早消息」刚取回来的那一段，
    /// 裁掉它等于让该操作毫无效果。
    func evictTailIfNeeded(messages: [Message]) -> [Message] {
        guard messages.count > maxRetainedCount else { return messages }
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
