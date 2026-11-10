import Foundation
import ProviderMessage

/// V5（ChatGPT）消息窗口的分页服务。
///
/// 封装消息时间线的「消息窗口管理」策略：通过 `MessageManaging` 的分页 API
/// 获取窗口数据，存储层可以在查询阶段限制返回数量，
/// 避免长会话每次刷新都物化全部消息。
///
/// 与 V4 一致：取数前先**剔除独立的 `.tool` 结果行**（工具结果消息从不进入
/// UI 分页窗口；工具信息由助手消息内联的 toolCalls 呈现）。
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

    /// 单页条数上限：超出即钳制，避免 `pageSize + 1` 溢出或 `suffix` 负数 trap。
    private static let maxPageSize = 200
    /// 窗口保留条数上限：超出即钳制，避免长会话把整段历史拉进内存。
    private static let maxRetainedMessages = 10_000

    /// - Important: 配置**一律钳制**，不使用 `assert` 拒绝。
    ///
    ///   `assert` 在 Release 下被移除，于是「Debug trap / Release 钳制」会得到
    ///   两种不同的行为，同一份配置在不同构建里表现不一致。
    ///   超出上限是**合法意图**（调用方想要更大的窗口），钳制即可；
    ///   非正数是**非法输入**，同样钳到 1 而不是终止进程。
    init(pageSize: Int = 40, maxRetainedCount: Int = 300) {
        self.pageSize = max(1, min(Self.maxPageSize, pageSize))
        self.maxRetainedCount = max(1, min(Self.maxRetainedMessages, maxRetainedCount))
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
    /// 返回 `nil` 表示「无需操作」：无更早消息 / 无当前消息基准 / 更早一页为空。
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
        // Important: 存储层已空（会话被清空）时，窗口必须**一起清空**。
        //
        //   否则界面会继续显示已被删除的消息 —— 存储与界面不一致。
        //   返回空数组而不是 nil，让调用方把窗口替换成空。
        guard !latestPage.isEmpty else {
            return current.isEmpty ? nil : RefreshTailResult(
                merged: [],
                hasEarlierMessages: false
            )
        }

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
    /// - Important: 裁掉的是**最旧**的窗口头部吗？不 —— 裁尾部。
    ///   尾部是「较新、远离可视区」的一段；用户翻历史时它不在视野内，
    ///   裁掉后由尾部刷新回填，不会丢失。
    func evictTailIfNeeded(messages: [Message]) -> [Message] {
        guard messages.count > maxRetainedCount else { return messages }
        return Array(messages.suffix(maxRetainedCount))
    }
}

// MARK: - 结果类型

/// 首屏加载结果。
struct LoadFirstPageResult: Equatable {
    let messages: [Message]
    let hasEarlierMessages: Bool
}

/// 向上翻页结果。
struct LoadEarlierResult: Equatable {
    /// prepend 前最早一条消息的 id；View 应把它钉回视口顶部。
    let anchorID: UUID?
    /// 更早一页的消息。
    let earlier: [Message]
    /// 是否还有更早消息。
    let hasEarlierMessages: Bool
}

/// 尾部刷新结果。
struct RefreshTailResult: Equatable {
    /// 合并后的窗口。
    let merged: [Message]
    /// `nil` 表示「本次没有改动该状态」。
    let hasEarlierMessages: Bool?
}
