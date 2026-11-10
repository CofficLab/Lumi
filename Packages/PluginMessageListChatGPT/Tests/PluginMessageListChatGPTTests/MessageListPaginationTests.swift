import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageListChatGPT

/// V5（ChatGPT）消息窗口分页测试。
///
/// 基准是 V5 方案 Task 5 的分页要求：
/// - pageSize 40、retained 300；
/// - 连续 prepend 不超过上限；
/// - tail eviction 后空档能回填，不出现永久缺段。
@Suite("V5 消息窗口分页")
@MainActor
struct MessageListPaginationTests {

    private func makeMessages(
        conversationID: UUID,
        count: Int
    ) -> [Message] {
        (0..<count).map { index in
            Message(
                id: UUID(),
                conversationID: conversationID,
                role: .user,
                content: "\(index)",
                createdAt: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }
    }

    // MARK: - 配置

    @Test("默认 pageSize 40、retained 300")
    func defaultBounds() {
        let service = MessageListPaginationService()
        #expect(service.pageSize == 40)
        #expect(service.maxRetainedCount == 300)
    }

    @Test("越界配置被钳制到安全范围")
    func outOfRangeConfigurationIsClamped() {
        let service = MessageListPaginationService(pageSize: 5_000, maxRetainedCount: 1_000_000)
        #expect(service.pageSize == 200)
        #expect(service.maxRetainedCount == 10_000)

        // 非正数钳到 1，不终止进程。
        let clamped = MessageListPaginationService(pageSize: 0, maxRetainedCount: -5)
        #expect(clamped.pageSize == 1)
        #expect(clamped.maxRetainedCount == 1)
    }

    // MARK: - 首屏

    @Test("首屏取最近一页并探测更早消息")
    func firstPageTakesMostRecentPage() async {
        let conversationID = UUID()
        let messages = StubMessageCapability()
        messages.messages = makeMessages(conversationID: conversationID, count: 100)

        let service = MessageListPaginationService(pageSize: 40, maxRetainedCount: 300)
        let result = await service.loadFirstPage(
            conversationID: conversationID,
            messageManager: messages
        )

        #expect(result.messages.count == 40)
        #expect(result.hasEarlierMessages)
        // 取的是**最近**的 40 条。
        #expect(result.messages.last?.content == "99")
    }

    @Test("首屏不足一页时不报告有更早消息")
    func firstPageWithoutEarlier() async {
        let conversationID = UUID()
        let messages = StubMessageCapability()
        messages.messages = makeMessages(conversationID: conversationID, count: 10)

        let service = MessageListPaginationService(pageSize: 40, maxRetainedCount: 300)
        let result = await service.loadFirstPage(
            conversationID: conversationID,
            messageManager: messages
        )

        #expect(result.messages.count == 10)
        #expect(!result.hasEarlierMessages)
    }

    @Test("没有消息能力时首屏为空")
    func firstPageWithoutCapability() async {
        let service = MessageListPaginationService()
        let result = await service.loadFirstPage(
            conversationID: UUID(),
            messageManager: nil
        )

        #expect(result.messages.isEmpty)
        #expect(!result.hasEarlierMessages)
    }

    // MARK: - 向上翻页

    @Test("向上翻页取更早一页并给出锚点")
    func loadEarlierReturnsAnchor() async {
        let conversationID = UUID()
        let messages = StubMessageCapability()
        messages.messages = makeMessages(conversationID: conversationID, count: 100)

        let service = MessageListPaginationService(pageSize: 40, maxRetainedCount: 300)
        let first = await service.loadFirstPage(
            conversationID: conversationID,
            messageManager: messages
        )
        let anchor = first.messages.first?.id

        let earlier = await service.loadEarlier(
            conversationID: conversationID,
            messageManager: messages,
            currentFirstID: anchor,
            hasEarlier: true
        )

        #expect(earlier != nil)
        #expect(earlier?.earlier.count == 40)
        #expect(earlier?.anchorID == anchor)
        // 更早一页的内容确实更早。
        #expect(earlier?.earlier.last?.content == "59")
    }

    @Test("没有更早消息时不翻页")
    func loadEarlierWithoutEarlierMessages() async {
        let service = MessageListPaginationService()
        let earlier = await service.loadEarlier(
            conversationID: UUID(),
            messageManager: StubMessageCapability(),
            currentFirstID: UUID(),
            hasEarlier: false
        )
        #expect(earlier == nil)
    }

    @Test("缺少当前首条基准时不翻页")
    func loadEarlierWithoutAnchor() async {
        let service = MessageListPaginationService()
        let earlier = await service.loadEarlier(
            conversationID: UUID(),
            messageManager: StubMessageCapability(),
            currentFirstID: nil,
            hasEarlier: true
        )
        #expect(earlier == nil)
    }

    // MARK: - 窗口回收

    @Test("连续 prepend 后窗口仍受上限约束")
    func repeatedPrependKeepsWindowBounded() {
        let service = MessageListPaginationService(pageSize: 40, maxRetainedCount: 300)
        var window = makeMessages(conversationID: UUID(), count: 200)

        // 模拟连续 prepend。
        for _ in 0..<10 {
            window = makeMessages(conversationID: UUID(), count: 40) + window
            window = service.evictTailIfNeeded(messages: window)
        }

        #expect(window.count <= 300)
    }

    @Test("窗口回收保留较新的一段")
    func evictionKeepsNewerMessages() {
        let service = MessageListPaginationService(pageSize: 40, maxRetainedCount: 300)
        let messages = makeMessages(conversationID: UUID(), count: 500)

        let evicted = service.evictTailIfNeeded(messages: messages)

        #expect(evicted.count == 300)
        #expect(evicted.last?.content == "499")
    }

    // MARK: - 尾部刷新

    @Test("尾部刷新覆盖最近一页")
    func tailRefreshReplacesLatestPage() async {
        let conversationID = UUID()
        let messages = StubMessageCapability()
        messages.messages = makeMessages(conversationID: conversationID, count: 60)

        let service = MessageListPaginationService(pageSize: 40, maxRetainedCount: 300)
        let first = await service.loadFirstPage(
            conversationID: conversationID,
            messageManager: messages
        )
        #expect(first.messages.count == 40)

        // 新消息到达。
        messages.messages.append(
            Message(
                conversationID: conversationID,
                role: .assistant,
                content: "新回复",
                createdAt: Date(timeIntervalSince1970: 1_000)
            )
        )

        let refreshed = await service.refreshTail(
            conversationID: conversationID,
            messageManager: messages,
            current: first.messages
        )

        #expect(refreshed != nil)
        // 窗口原有 40 条，新消息落在尾部 —— 合并后是 41 条。
        #expect(refreshed?.merged.count == 41)
        #expect(refreshed?.merged.last?.content == "新回复")
    }

    @Test("存储被清空时尾部刷新清空窗口")
    func tailRefreshClearsWindowWhenStorageEmpty() async {
        let conversationID = UUID()
        let messages = StubMessageCapability()
        messages.messages = makeMessages(conversationID: conversationID, count: 10)

        let service = MessageListPaginationService(pageSize: 40, maxRetainedCount: 300)
        let first = await service.loadFirstPage(
            conversationID: conversationID,
            messageManager: messages
        )

        messages.messages = []
        let refreshed = await service.refreshTail(
            conversationID: conversationID,
            messageManager: messages,
            current: first.messages
        )

        #expect(refreshed?.merged.isEmpty == true)
        #expect(refreshed?.hasEarlierMessages == false)
    }

    @Test("尾部刷新在窗口为空时铺上最近一页")
    func tailRefreshFillsEmptyWindow() async {
        let conversationID = UUID()
        let messages = StubMessageCapability()
        messages.messages = makeMessages(conversationID: conversationID, count: 5)

        let service = MessageListPaginationService(pageSize: 40, maxRetainedCount: 300)
        let refreshed = await service.refreshTail(
            conversationID: conversationID,
            messageManager: messages,
            current: []
        )

        #expect(refreshed?.merged.count == 5)
    }

    @Test("没有消息能力时尾部刷新不做事")
    func tailRefreshWithoutCapability() async {
        let service = MessageListPaginationService()
        let refreshed = await service.refreshTail(
            conversationID: UUID(),
            messageManager: nil,
            current: []
        )
        #expect(refreshed == nil)
    }
}
