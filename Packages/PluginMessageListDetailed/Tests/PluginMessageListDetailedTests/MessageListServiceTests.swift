import Foundation
import Testing
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import ProviderToolManager
@testable import PluginMessageListDetailed

@MainActor
@Test("消息行过滤工具结果，并把空正文工具调用合并为 turn activity")
func messageRowsFilterAndMergeToolExecutionMessages() {
    let conversationID = UUID()
    let turnID = UUID()
    let firstToolMessage = makeMessage(
        conversationID: conversationID,
        role: .assistant,
        content: "",
        turnID: turnID,
        toolCalls: [MessageToolCall(id: "call-1", name: "read", arguments: "{}")]
    )
    let secondToolMessage = makeMessage(
        conversationID: conversationID,
        role: .assistant,
        content: "...",
        turnID: turnID,
        toolCalls: [MessageToolCall(id: "call-2", name: "write", arguments: "{}")]
    )
    let answer = makeMessage(conversationID: conversationID, role: .assistant, content: "done")
    let toolResult = makeMessage(conversationID: conversationID, role: .tool, content: "private result")
    let status = makeMessage(conversationID: conversationID, role: .status, content: "thinking")

    let rows = MessageListRowBuilder().buildHistory(
        persisted: [firstToolMessage, secondToolMessage, toolResult, status, answer],
        conversationID: conversationID,
        verbosity: .standard,
        hidesStatus: true
    )

    #expect(rows.count == 2)
    #expect(rows[0].id == firstToolMessage.id)
    #expect(rows[0].turnID == turnID)
    #expect(rows[0].renderKind == "turn-activity")
    #expect(rows[0].toolCalls?.map(\.id) == ["call-1", "call-2"])
    #expect(rows[1].id == answer.id)
    #expect(!rows.contains { $0.role == .tool || $0.role == .status })
}

@MainActor
@Test("没有选中会话时保留原始行，且历史工具组使用兼容 render kind")
func messageRowsPreserveUnscopedMessagesAndLegacyGroups() {
    let conversationID = UUID()
    let first = makeMessage(
        conversationID: conversationID,
        role: .assistant,
        content: "",
        toolCalls: [MessageToolCall(id: "old-1", name: "read", arguments: "{}")]
    )
    let second = makeMessage(
        conversationID: conversationID,
        role: .assistant,
        content: "  ",
        toolCalls: [MessageToolCall(id: "old-2", name: "write", arguments: "{}")]
    )
    let toolResult = makeMessage(conversationID: conversationID, role: .tool, content: "hidden")
    let builder = MessageListRowBuilder()

    let unscoped = builder.buildHistory(
        persisted: [first, second, toolResult],
        conversationID: nil,
        verbosity: .standard
    )
    let legacy = builder.buildHistory(
        persisted: [first, second, toolResult],
        conversationID: conversationID,
        verbosity: .standard
    )

    #expect(unscoped.map(\.id) == [first.id, second.id, toolResult.id])
    #expect(legacy.count == 1)
    #expect(legacy[0].renderKind == "tool-step-group")
    #expect(legacy[0].toolCalls?.map(\.id) == ["old-1", "old-2"])
}

@Test("空响应判断排除错误和工具调用消息")
func messageDerivedPredicatesDistinguishEmptyResponses() {
    let conversationID = UUID()
    let empty = makeMessage(conversationID: conversationID, role: .assistant, content: " \n")
    let error = makeMessage(conversationID: conversationID, role: .assistant, content: "", isError: true)
    let withTool = makeMessage(
        conversationID: conversationID,
        role: .assistant,
        content: "",
        toolCalls: [MessageToolCall(id: "call", name: "read", arguments: "{}")]
    )

    #expect(empty.isEmptyResponse)
    #expect(!error.isEmptyResponse)
    #expect(!withTool.isEmptyResponse)
    #expect(withTool.isToolExecutionOnly)
}

@MainActor
@Test("首屏取最近 pageSize 条并探测是否存在更早消息")
func paginationLoadsLatestPageAndDetectsEarlierMessages() async {
    let conversationID = UUID()
    let messages = (0..<3).map { index in
        makeMessage(conversationID: conversationID, role: .user, content: "\(index)")
    }
    let manager = StubMessageListMessageCapability(page: messages)
    let service = MessageListPaginationService(pageSize: 2, maxRetainedCount: 10)

    let result = await service.loadFirstPage(conversationID: conversationID, messageManager: manager)

    #expect(result.messages.map(\.id) == messages.suffix(2).map(\.id))
    #expect(result.hasEarlierMessages)
    #expect(manager.pageRequests.first?.limit == 3)
    #expect(manager.pageRequests.first?.beforeMessageID == nil)
    #expect(manager.pageRequests.first?.includesToolMessages == false)
}

@MainActor
@Test("向上翻页保留锚点，并重新检查是否还有更早消息")
func paginationLoadsEarlierPageAroundAnchor() async {
    let conversationID = UUID()
    // stub 按 createdAt 排序，必须给递增时间戳，否则排序结果不确定。
    let base = Date(timeIntervalSince1970: 100)
    // 游标分页：从 anchor 之前截取。anchor 必须在数据集中，否则取不到更早消息。
    let anchor = makeMessage(
        conversationID: conversationID, role: .user, content: "anchor",
        createdAt: base.addingTimeInterval(3)
    )
    let earlier = [
        makeMessage(
            conversationID: conversationID, role: .user, content: "one",
            createdAt: base
        ),
        makeMessage(
            conversationID: conversationID, role: .user, content: "two",
            createdAt: base.addingTimeInterval(1)
        ),
        makeMessage(
            conversationID: conversationID, role: .user, content: "three",
            createdAt: base.addingTimeInterval(2)
        ),
    ]
    let manager = StubMessageListMessageCapability(
        window: [anchor],
        earlier: earlier,
        hasEarlier: true
    )
    let service = MessageListPaginationService(pageSize: 2, maxRetainedCount: 10)

    let result = await service.loadEarlier(
        conversationID: conversationID,
        messageManager: manager,
        currentFirstID: anchor.id,
        hasEarlier: true
    )

    #expect(result?.anchorID == anchor.id)
    // pageSize=2 → 只取 anchor 之前最近的两条（two / three）。
    #expect(result?.earlier.map(\.id) == earlier.suffix(2).map(\.id))
    // 这两条之前仍有 "one" → 还有更早消息。
    #expect(result?.hasEarlierMessages == true)
    #expect(manager.pageRequests.first?.beforeMessageID == anchor.id)
    #expect(manager.earlierRequests.first?.beforeMessageID == earlier.suffix(2).first?.id)
}

@MainActor
@Test("尾部刷新覆盖重叠窗口，避免无重叠时打断历史浏览")
func paginationRefreshesOnlyAnOverlappingTail() async {
    let conversationID = UUID()
    let older = makeMessage(conversationID: conversationID, role: .user, content: "older")
    let overlap = makeMessage(conversationID: conversationID, role: .user, content: "stale")
    let updatedOverlap = makeMessage(
        id: overlap.id,
        conversationID: conversationID,
        role: .user,
        content: "updated"
    )
    let newTail = makeMessage(conversationID: conversationID, role: .assistant, content: "new")
    let manager = StubMessageListMessageCapability(page: [updatedOverlap, newTail])
    let service = MessageListPaginationService(pageSize: 2, maxRetainedCount: 10)

    let merged = await service.refreshTail(
        conversationID: conversationID,
        messageManager: manager,
        current: [older, overlap]
    )
    let noOverlap = await service.refreshTail(
        conversationID: conversationID,
        messageManager: StubMessageListMessageCapability(page: [newTail]),
        current: [older]
    )

    #expect(merged?.merged.map(\.id) == [older.id, updatedOverlap.id, newTail.id])
    #expect(merged?.hasEarlierMessages == nil)
    #expect(noOverlap.map { _ in false } ?? true)
}

@MainActor
@Test("空窗口首刷补查 earlier，尾部回收只在离开底部时执行")
func paginationInitialRefreshAndTailEviction() async {
    let conversationID = UUID()
    let base = Date(timeIntervalSince1970: 100)
    // 首屏窗口只含最近一条，其前还有更早消息 → hasEarlierMessages == true。
    let oldest = makeMessage(
        conversationID: conversationID, role: .user, content: "oldest",
        createdAt: base
    )
    let newest = makeMessage(
        conversationID: conversationID, role: .user, content: "0",
        createdAt: base.addingTimeInterval(1)
    )
    let page = [newest]
    let retained = (0..<3).map { index in
        makeMessage(
            conversationID: conversationID, role: .user, content: "retained-\(index)",
            createdAt: base.addingTimeInterval(TimeInterval(index))
        )
    }
    let manager = StubMessageListMessageCapability(window: page, earlier: [oldest])
    let service = MessageListPaginationService(pageSize: 2, maxRetainedCount: 2)

    let initial = await service.refreshTail(conversationID: conversationID, messageManager: manager, current: [])
    let atBottom = service.evictTailIfNeeded(messages: retained, isAtBottom: true)
    let awayFromBottom = service.evictTailIfNeeded(messages: retained, isAtBottom: false)

    #expect(initial?.merged.map(\.id) == page.map(\.id))
    #expect(initial?.hasEarlierMessages == true)
    #expect(atBottom.map(\.id) == retained.map(\.id))
    #expect(awayFromBottom.map(\.id) == retained.prefix(2).map(\.id))
}

@MainActor
@Test("尾部刷新门将并发通知合并成当前轮和至多一轮尾随刷新")
func tailRefreshGateCoalescesOverlappingRequests() async {
    let gate = MessageListTailRefreshGate()
    var operationCount = 0
    var releaseFirstOperation: CheckedContinuation<Void, Never>?
    let activeRun = Task { @MainActor in
        await gate.run {
            operationCount += 1
            if operationCount == 1 {
                await withCheckedContinuation { continuation in
                    releaseFirstOperation = continuation
                }
            }
            return operationCount == 1
        }
    }

    while releaseFirstOperation == nil {
        await Task.yield()
    }
    let overlappingRun = await gate.run {
        operationCount += 1
        return false
    }
    releaseFirstOperation?.resume()

    let activeResult = await activeRun.value

    #expect(!overlappingRun)
    #expect(activeResult)
    #expect(operationCount == 2)
}

@Test("通知按当前会话筛选，消息时间相同时按 UUID 稳定排序")
func messageNotificationAndOrderingAreStable() {
    let conversationID = UUID()
    let otherConversationID = UUID()
    let earlierID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let laterID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let date = Date(timeIntervalSince1970: 42)
    let later = makeMessage(id: laterID, conversationID: conversationID, role: .user, content: "later", createdAt: date)
    let earlier = makeMessage(id: earlierID, conversationID: conversationID, role: .user, content: "earlier", createdAt: date)

    #expect(MessageListNotificationFilter.shouldHandle(eventConversationID: nil, selectedConversationID: conversationID))
    #expect(MessageListNotificationFilter.shouldHandle(eventConversationID: conversationID, selectedConversationID: conversationID))
    #expect(!MessageListNotificationFilter.shouldHandle(eventConversationID: otherConversationID, selectedConversationID: conversationID))
    #expect(!MessageListNotificationFilter.shouldHandle(eventConversationID: nil, selectedConversationID: nil))
    #expect(messageOrdering(earlier, later))
    #expect(!messageOrdering(later, earlier))
}

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

@MainActor
final class StubMessageListMessageCapability: MessageListMessageCapability {
    /// 首屏窗口。尾部刷新测试用它模拟「服务端已写入新消息」。
    private(set) var page: [Message]
    /// 完整消息集（按时间升序）。分页请求从 `beforeMessageID` 之前截取。
    private(set) var allMessages: [Message]
    var hasEarlier: Bool
    private(set) var pageRequests: [(limit: Int, beforeMessageID: UUID?, includesToolMessages: Bool)] = []
    private(set) var earlierRequests: [(beforeMessageID: UUID?, includesToolMessages: Bool)] = []

    init(page: [Message], hasEarlier: Bool = false) {
        self.page = page
        self.allMessages = page.sorted { $0.createdAt < $1.createdAt }
        self.hasEarlier = hasEarlier
    }

    /// 显式提供「首屏窗口 + 更早历史」，用于翻页 / prepend 测试。
    init(window: [Message], earlier: [Message], hasEarlier: Bool = false) {
        self.page = window
        self.allMessages = (earlier + window).sorted { $0.createdAt < $1.createdAt }
        self.hasEarlier = hasEarlier
    }

    /// 模拟服务端状态变化：整体替换数据源，丢弃翻页历史。
    func setPage(_ newPage: [Message]) {
        page = newPage
        allMessages = newPage.sorted { $0.createdAt < $1.createdAt }
    }

    func messagesSnapshot(in conversationID: UUID) async -> [Message] { page }

    func messagePageAsync(
        for conversationID: UUID,
        limit: Int,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) async -> [Message] {
        pageRequests.append((limit, beforeMessageID, includesToolMessages))
        // 首屏/尾部刷新（无游标）只返回当前窗口；
        // 翻页（有游标）才回溯到窗口之前的历史。
        let source: [Message]
        if let beforeMessageID,
           let index = allMessages.firstIndex(where: { $0.id == beforeMessageID }) {
            source = Array(allMessages[..<index])
        } else {
            source = page
        }
        return Array(source.suffix(limit))
    }

    func hasEarlierMessagesAsync(
        for conversationID: UUID,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) async -> Bool {
        earlierRequests.append((beforeMessageID, includesToolMessages))
        guard let beforeMessageID,
              let index = allMessages.firstIndex(where: { $0.id == beforeMessageID }) else {
            return hasEarlier
        }
        return index > 0
    }
}
