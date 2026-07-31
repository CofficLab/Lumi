import Foundation
import LumiKernel

/// Message Timeline Pagination Service
///
/// 封装消息时间线的"消息窗口管理"策略(沉淀自原
/// `MessageListPlugin.MessagePaginationService`):
///
/// 1. **首屏加载** —— 加载最近一页(pageSize 条),并探测是否还有更早消息。
/// 2. **向上翻页** —— 在当前最早一条之前加载更早一页并 prepend;未读到则
///    保持原状;过期会话切换时丢弃结果。
/// 3. **尾部刷新** —— 重新拉最近一页,与当前 `messages` 比对并覆盖尾部重叠区;
///    无重叠且用户正在翻历史时不强行覆盖(避免破坏视觉位置)。
/// 4. **窗口回收** —— 当内存中消息超过 `maxRetainedCount` 时丢弃尾部(较新、
///    远离可视区的),仅在用户**不在底部**时执行(避免裁掉正在流式的尾部)。
///
/// 数据库读取来自 `MessageManager`,其方法标 `nonisolated`,故可安全地
/// 在 `Task.detached` 中执行 —— 本服务统一封装后台读取切换,
/// 调用方无需关心线程。
///
/// 本服务**不持有状态**:`messages`、`hasEarlierMessages`、`activeConversationID`
/// 均由 `MessageTimelineStore` 持有,本服务只对它们做变换。
@MainActor
struct MessageListPaginationService {
    let pageSize: Int
    let maxRetainedCount: Int

    init(pageSize: Int = 40, maxRetainedCount: Int = 300) {
        self.pageSize = pageSize
        self.maxRetainedCount = maxRetainedCount
    }

    /// 加载首屏(最近一页)+ 是否还有更早消息。
    ///
    /// 无可用 `messageManager`(kernel 初始化未完成)时,返回空状态。
    /// `activeConversationID` 与请求 id 不一致时,结果被丢弃(防止过期返回
    /// 覆盖用户切到的新会话)。该过期判定由 `MessageTimelineStore` 持有
    /// `activeConversationID`,本服务不参与。
    ///
    /// - Parameters:
    ///   - conversationID: 目标会话 ID。
    ///   - messageManager: 数据访问服务;若为 `nil` 则按"无可用结果"处理。
    func loadFirstPage(
        conversationID: UUID,
        messageManager: (any MessageManaging)?
    ) async -> LoadFirstPageResult {
        guard let messageManager else {
            return LoadFirstPageResult(messages: [], hasEarlierMessages: false)
        }
        let page: [LumiChatMessage]? = await read {
            messageManager.messagePage(
                for: conversationID, limit: pageSize, beforeMessageID: nil
            )
        }
        let safePage = page ?? []
        let hasEarlier: Bool = await read {
            messageManager.hasEarlierMessages(
                for: conversationID, beforeMessageID: safePage.first?.id
            )
        } ?? false
        return LoadFirstPageResult(
            messages: safePage, hasEarlierMessages: hasEarlier
        )
    }

    /// 向上翻页:在当前最早一条之前加载更早一页。
    ///
    /// 返回 `nil` 表示以下"无需操作"场景之一:
    /// - 无更早消息(`hasEarlier == false`)
    /// - 没有当前消息可供基准(`currentFirstID == nil`)
    /// - DB 返回的更早一页为空
    ///
    /// 注意:"是否已在加载"由调用方(`MessageTimelineStore`)用
    /// `isLoadingEarlier` 保证一次只有一次调用。本服务不参与 reentrancy 判定,
    /// 保持纯粹。
    ///
    /// 返回结果时,调用方应:更新 `messages = earlier + messages`、
    /// `hasEarlierMessages = stillHasEarlier`,然后由 UI 把 `anchorID`
    /// 钉回视口顶部。
    func loadEarlier(
        conversationID: UUID,
        messageManager: (any MessageManaging)?,
        currentFirstID: UUID?,
        hasEarlier: Bool
    ) async -> LoadEarlierResult? {
        guard hasEarlier,
              let currentFirstID,
              let messageManager else { return nil }
        let earlier: [LumiChatMessage]? = await read {
            messageManager.messagePage(
                for: conversationID, limit: pageSize, beforeMessageID: currentFirstID
            )
        }
        guard let earlier, !earlier.isEmpty else { return nil }
        let stillHas: Bool = await read {
            messageManager.hasEarlierMessages(
                for: conversationID, beforeMessageID: earlier.first?.id
            )
        } ?? false
        return LoadEarlierResult(
            anchorID: currentFirstID,
            earlier: earlier,
            hasEarlierMessages: stillHas
        )
    }

    /// 尾部刷新:用最近一页覆盖 `messages` 尾部,保留头部更早的历史。
    ///
    /// 返回 `nil` 表示无需操作:
    /// - 缺 `messageManager`;或
    /// - 最近一页为空;或
    /// - 与当前 `messages` 完全无重叠且当前有内容——避免破坏用户翻历史时的
    ///   视觉位置;**返回 `nil` 后 UI 应另行提示"有新消息"按钮**。
    func refreshTail(
        conversationID: UUID,
        messageManager: (any MessageManaging)?,
        current: [LumiChatMessage]
    ) async -> RefreshTailResult? {
        guard let messageManager else { return nil }
        let latestPage: [LumiChatMessage]? = await read {
            messageManager.messagePage(
                for: conversationID, limit: pageSize, beforeMessageID: nil
            )
        }
        guard let latestPage, !latestPage.isEmpty else { return nil }

        let latestIDs = Set(latestPage.map(\.id))
        if let firstOverlapIndex = current.firstIndex(where: { latestIDs.contains($0.id) }) {
            // 找到重叠位置:保留头部更早历史,拼接最新页
            let merged = Array(current[..<firstOverlapIndex]) + latestPage
            return RefreshTailResult(merged: merged, hasEarlierMessages: nil)
        }
        if current.isEmpty {
            // 从无到有:直接把最近一页铺上,并补查 hasEarlier。
            let hasEarlier: Bool = await read {
                messageManager.hasEarlierMessages(
                    for: conversationID, beforeMessageID: latestPage.first?.id
                )
            } ?? false
            return RefreshTailResult(
                merged: latestPage,
                hasEarlierMessages: hasEarlier
            )
        }
        // 无重叠且当前有内容:用户在翻历史,不要强行覆盖。
        return nil
    }

    /// 窗口回收:超过 `maxRetainedCount` 时丢弃尾部较新消息。
    ///
    /// **仅在用户不在底部时执行**(`isAtBottom == false`)——
    /// 防止裁掉正在流式的尾部。
    ///
    /// - Returns: 若发生裁剪,返回裁剪后的列表;否则原样返回。
    func evictTailIfNeeded(
        messages: [LumiChatMessage], isAtBottom: Bool
    ) -> [LumiChatMessage] {
        guard messages.count > maxRetainedCount, !isAtBottom else { return messages }
        let overflow = messages.count - maxRetainedCount
        var trimmed = messages
        trimmed.removeLast(overflow)
        return trimmed
    }

    // MARK: - Helpers

    /// 在后台线程执行一段 `Sendable` 读操作,避免阻塞主线程。
    ///
    /// 闭包内调用 `MessageManaging` 的 `nonisolated` 同步方法,结果从
    /// `Task.detached` 中取出。注意 Swift 编译器会把 `read { ... }`
    /// 中的 trailing closure 推导为 `@Sendable () -> T`,捕获 `messageManager`
    /// (Sendable) 是合法的。
    private func read<T: Sendable>(
        _ body: @escaping @Sendable () -> T
    ) async -> T? {
        await Task.detached(priority: .userInitiated) { body() }.value
    }
}

// MARK: - Results

/// `loadFirstPage` 的返回结构,避免返回元组/多值难命名。
struct LoadFirstPageResult: Sendable {
    let messages: [LumiChatMessage]
    let hasEarlierMessages: Bool
}

/// `loadEarlier` 的返回结构。`anchorID` 是 prepend 前最早一条消息的 id,
/// UI 应在 prepend 后把它钉回视口顶部。
struct LoadEarlierResult: Sendable {
    let anchorID: UUID
    let earlier: [LumiChatMessage]
    let hasEarlierMessages: Bool
}

/// `refreshTail` 的返回结构。`hasEarlierMessages` 仅在"从空到非空"时填值;
/// 其他情况调用方应保留旧值(传 `nil`)。
struct RefreshTailResult: Sendable {
    let merged: [LumiChatMessage]
    let hasEarlierMessages: Bool?
}
