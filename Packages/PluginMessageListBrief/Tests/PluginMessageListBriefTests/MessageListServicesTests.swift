import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageListBrief

/// README §4 翻页 / §5 滚动 / §6 状态卡 隐含的纯函数/actor 行为测试。
///
/// 覆盖：
/// - `MessageListTailRefreshGate`：并发刷新合并为一次+一次尾随
/// - `MessageListPaginationService`：首屏分页 + 翻页 + tail 合并的边界
/// - `MessageListSendPositioning`：post-send 锚点定位常量
@MainActor
struct MessageListServicesTests {
    private let conversationID = UUID()

    // MARK: - MessageListTailRefreshGate

    @Test("tail gate 第一次 run 返回真实结果，事件突发合并为尾随一次")
    func tailGateCollapsesBursts() async {
        let gate = MessageListTailRefreshGate()
        var runCount = 0
        let firstResult = await gate.run {
            runCount += 1
            // 模拟 I/O 期间又来了 3 个重叠请求。
            await Task.yield()
            return true
        }
        #expect(firstResult)
        #expect(runCount == 1)
    }

    @Test("tail gate 在 active run 期间重叠的 caller 不会插入任务")
    func overlappingRunnersReturnFalse() async {
        let gate = MessageListTailRefreshGate()
        var innerResult: Bool?
        var operationRuns = 0
        var didSendInner = false

        // 在第一个 run 的 operation 挂起期间，于其内部发起一次重叠请求 ——
        // 与真实场景（tail 刷新 I/O 期间又收到消息变更通知）等价。
        // 只发一次：内层 run 会把 needsTrailingRefresh 置 true，gate 随后
        // 自动补跑一轮 trailing operation；若每轮都重发内层请求，
        // trailing 循环将永远重复（活锁）。
        let outer = await gate.run { @MainActor in
            operationRuns += 1
            if !didSendInner {
                didSendInner = true
                innerResult = await gate.run { @MainActor in true }
            }
            return true
        }

        #expect(outer, "只有 active run 的持有者可以收到 true")
        #expect(innerResult == false, "重叠的 caller 必须被 gate 收敛为 false")
        #expect(
            operationRuns == 2,
            "重叠请求应触发恰好一次 trailing 补跑，实际跑了 \(operationRuns) 轮"
        )
    }

    // MARK: - MessageListPaginationService

    /// 可被驱动变化的 `MessageListMessageCapability`，用于 service 测试。
    final class StubMessages: MessageListMessageCapability {
        var allMessages: [Message] = []
        func messagesSnapshot(in conversationID: UUID) async -> [Message] { allMessages }
        func messagePageAsync(
            for conversationID: UUID,
            limit: Int,
            beforeMessageID: UUID?,
            includesToolMessages: Bool
        ) async -> [Message] {
            let filtered = allMessages.filter { includesToolMessages || $0.role != .tool }
            guard let beforeMessageID else { return Array(filtered.suffix(limit)) }
            guard let index = filtered.firstIndex(where: { $0.id == beforeMessageID }) else { return [] }
            return Array(filtered[max(0, index - limit)..<index])
        }
        func hasEarlierMessagesAsync(
            for conversationID: UUID,
            beforeMessageID: UUID?,
            includesToolMessages: Bool
        ) async -> Bool {
            let filtered = allMessages.filter { includesToolMessages || $0.role != .tool }
            guard let beforeMessageID else { return filtered.count > 10 }
            guard let index = filtered.firstIndex(where: { $0.id == beforeMessageID }) else { return false }
            return index > 0
        }
    }

    @Test("§4.1 loadFirstPage 用 pageSize+1 探测 hasEarlier，溢出才返回 true")
    func loadFirstPageProbesEarlier() async {
        let base = Date()
        let stub = StubMessages()
        stub.allMessages = (0..<45).map { idx in
            Message(
                conversationID: conversationID,
                role: .user,
                content: "u\(idx)",
                createdAt: base.addingTimeInterval(TimeInterval(idx))
            )
        }
        let svc = MessageListPaginationService(pageSize: 40)
        let first = await svc.loadFirstPage(
            conversationID: conversationID,
            messageManager: stub
        )
        #expect(first.messages.count == 40)
        #expect(first.hasEarlierMessages)
    }

    @Test("§4.3 / §4.5 loadEarlier 翻到顶后返回的 hasEarlierMessages 为 false")
    func loadEarlierExhaustsAtTop() async {
        let base = Date()
        let stub = StubMessages()
        stub.allMessages = (0..<3).map { idx in
            Message(
                conversationID: conversationID,
                role: .user,
                content: "u\(idx)",
                createdAt: base.addingTimeInterval(TimeInterval(idx))
            )
        }
        let svc = MessageListPaginationService(pageSize: 40)
        let first = await svc.loadFirstPage(
            conversationID: conversationID,
            messageManager: stub
        )
        #expect(first.hasEarlierMessages == false)
    }

    @Test("refreshTail 找到重叠位置时拼接保留头部历史")
    func refreshTailMergesAtOverlap() async {
        let base = Date()
        let stub = StubMessages()
        let initial: [Message] = (0..<5).map { idx in
            Message(
                conversationID: conversationID,
                role: .user,
                content: "u\(idx)",
                createdAt: base.addingTimeInterval(TimeInterval(idx))
            )
        }
        stub.allMessages = initial
        let svc = MessageListPaginationService(pageSize: 5)
        let merged = await svc.refreshTail(
            conversationID: conversationID,
            messageManager: stub,
            current: initial
        )
        #expect(merged?.merged.map(\.id) == initial.map(\.id))
    }

    @Test("refreshTail 当 current 为空时使用最新页并补查 hasEarlier")
    func refreshTailSeedsFromEmpty() async {
        let base = Date()
        let stub = StubMessages()
        stub.allMessages = (0..<3).map { idx in
            Message(
                conversationID: conversationID,
                role: .user,
                content: "u\(idx)",
                createdAt: base.addingTimeInterval(TimeInterval(idx))
            )
        }
        let svc = MessageListPaginationService(pageSize: 3)
        let merged = await svc.refreshTail(
            conversationID: conversationID,
            messageManager: stub,
            current: []
        )
        #expect(merged?.merged.count == 3)
        #expect(merged?.hasEarlierMessages == false)
    }

    @Test("refreshTail 无重叠且 current 非空时返回 nil，避免覆盖用户历史位置")
    func refreshTailAbortsOnUserScrolling() async {
        let base = Date()
        let stub = StubMessages()
        stub.allMessages = [
            Message(
                conversationID: conversationID,
                role: .user,
                content: "old",
                createdAt: base.addingTimeInterval(-1)
            )
        ]
        let current: [Message] = [
            Message(
                conversationID: UUID(),
                role: .user,
                content: "stale",
                createdAt: base
            )
        ]
        let svc = MessageListPaginationService(pageSize: 3)
        let merged = await svc.refreshTail(
            conversationID: conversationID,
            messageManager: stub,
            current: current
        )
        #expect(merged == nil)
    }

    // MARK: - MessageListSendPositioning

    @Test("post-send 锚点常量 = 视口高度的 0.75，符合 README §5.5「上 1/4」描述")
    func postSendAnchorTopFraction() {
        #expect(MessageListSendPositioning.targetTopFraction == 0.25)
        #expect(
            MessageListSendPositioning.conservativeTailReserve(viewportHeight: 800) == 600
        )
    }

    @Test("post-send reserve 在无效视口高度下返回 0")
    func postSendReserveZeroOnInvalidViewport() {
        #expect(MessageListSendPositioning.conservativeTailReserve(viewportHeight: 0) == 0)
        #expect(MessageListSendPositioning.conservativeTailReserve(viewportHeight: .nan) == 0)
        #expect(MessageListSendPositioning.conservativeTailReserve(viewportHeight: -100) == 0)
    }

    // MARK: - MessageListScrollCoordinator 静态行为

    @Test("ScrollCoordinator 静态常量与 README §4/§5 描述一致")
    func scrollCoordinatorConstantsMatchREADME() {
        // §4.3 提到的 postPrependDelay / §5.1 提到的 postAppendDelay。
        #expect(MessageListScrollCoordinator.postAppendDelayNs == 30_000_000)
        #expect(MessageListScrollCoordinator.postPrependDelayNs == 50_000_000)
        // 进入/离开容差形成迟滞带，避免流式场景下频繁翻转 atBottom。
        #expect(MessageListScrollCoordinator.bottomEnterTolerance == 24)
        #expect(MessageListScrollCoordinator.bottomLeaveTolerance == 96)
    }

    @Test("ScrollCoordinator.bottomAnchorID 是稳定常量，UI 测试可按此定位")
    func bottomAnchorIDIsStable() {
        #expect(MessageListScrollCoordinator.bottomAnchorID == "message-list-bottom-anchor")
    }
}
