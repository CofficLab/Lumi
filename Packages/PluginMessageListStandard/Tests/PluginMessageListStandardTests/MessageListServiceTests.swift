import Foundation
import Testing
import ProviderAgentLoop
import ProviderConversation
import ProviderMessage
import ProviderToolManager
@testable import PluginMessageListStandard

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
    // 合成行的 id 由**组内成员集合**派生，不再复用首条消息的 id。
    // 原因：V2/V3 用 `ForEach(historyRows)` + `.id(message.id)` 作为行的身份，
    // id 不变时组内新增成员不会触发重新物化，新并入的挂起工具行
    // （及其授权卡片）就画不出来 —— 用户只看到「等待你的输入…」。
    // 参见 `MessageListSuspendedToolRowIdentityTests`。
    #expect(rows[0].id != firstToolMessage.id)
    #expect(rows[0].id != secondToolMessage.id)
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
    let anchorID = UUID()
    let earlier = [
        makeMessage(conversationID: conversationID, role: .user, content: "one"),
        makeMessage(conversationID: conversationID, role: .user, content: "two"),
    ]
    let manager = StubMessageListMessageCapability(page: earlier, hasEarlier: true)
    let service = MessageListPaginationService(pageSize: 2, maxRetainedCount: 10)

    let result = await service.loadEarlier(
        conversationID: conversationID,
        messageManager: manager,
        currentFirstID: anchorID,
        hasEarlier: true
    )

    #expect(result?.anchorID == anchorID)
    #expect(result?.earlier.map(\.id) == earlier.map(\.id))
    #expect(result?.hasEarlierMessages == true)
    #expect(manager.pageRequests.first?.beforeMessageID == anchorID)
    #expect(manager.earlierRequests.first?.beforeMessageID == earlier.first?.id)
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
@Test("尾部刷新回填空档后，窗口必须保持时间升序且无重复")
func paginationBackfillsGapKeepingWindowOrdered() async {
    let conversationID = UUID()
    let base = Date(timeIntervalSince1970: 1_700_000_000)
    let window = (0..<2).map { index in
        makeMessage(
            conversationID: conversationID,
            role: .user,
            content: "w\(index)",
            createdAt: base.addingTimeInterval(Double(index))
        )
    }
    let gap = (0..<2).map { index in
        makeMessage(
            conversationID: conversationID,
            role: .user,
            content: "g\(index)",
            createdAt: base.addingTimeInterval(Double(2 + index))
        )
    }
    let page = (0..<2).map { index in
        makeMessage(
            conversationID: conversationID,
            role: .user,
            content: "p\(index)",
            createdAt: base.addingTimeInterval(Double(4 + index))
        )
    }
    // 本地刚插入、还没落库的消息：不在最近一页里，但必须留在窗口末尾。
    let pending = makeMessage(
        conversationID: conversationID,
        role: .user,
        content: "pending",
        createdAt: base.addingTimeInterval(6)
    )

    let manager = StubMessageListMessageCapability(page: page, earlierPage: gap)
    let service = MessageListPaginationService(pageSize: 2, maxRetainedCount: 10)

    let result = await service.refreshTail(
        conversationID: conversationID,
        messageManager: manager,
        current: window + [pending]
    )
    let ids = result?.merged.map(\.id) ?? []
    let timestamps = result?.merged.map(\.createdAt) ?? []

    #expect(ids == (window + gap + page + [pending]).map(\.id))
    #expect(timestamps == timestamps.sorted(), "回填后的窗口必须保持时间升序")
    #expect(Set(ids).count == ids.count, "回填后的窗口不得出现重复消息")
}

@MainActor
@Test("空窗口首刷补查 earlier，窗口超上限时一律回收尾部")
func paginationInitialRefreshAndTailEviction() async {
    let conversationID = UUID()
    let page = (0..<2).map { index in
        makeMessage(conversationID: conversationID, role: .user, content: "\(index)")
    }
    let retained = (0..<3).map { index in
        makeMessage(conversationID: conversationID, role: .user, content: "retained-\(index)")
    }
    let manager = StubMessageListMessageCapability(page: page, hasEarlier: true)
    let service = MessageListPaginationService(pageSize: 2, maxRetainedCount: 2)

    let initial = await service.refreshTail(conversationID: conversationID, messageManager: manager, current: [])
    let overLimit = service.evictTailIfNeeded(messages: retained)
    let withinLimit = service.evictTailIfNeeded(messages: Array(retained.prefix(2)))

    #expect(initial?.merged.map(\.id) == page.map(\.id))
    #expect(initial?.hasEarlierMessages == true)
    // 窗口上限无条件生效：超限时回收尾部，未超限时原样返回。
    #expect(overLimit.map(\.id) == retained.prefix(2).map(\.id))
    #expect(withinLimit.map(\.id) == retained.prefix(2).map(\.id))
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
