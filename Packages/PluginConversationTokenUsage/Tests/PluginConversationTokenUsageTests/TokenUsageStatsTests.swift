import Foundation
import ProviderMessage
import Testing
@testable import PluginConversationTokenUsage

// MARK: - 用量聚合

@Test func tokenUsageAggregatesInputAndOutputTokens() {
    let conversationID = UUID()
    let messages = [
        Message(
            conversationID: conversationID,
            role: .assistant,
            content: "first",
            inputTokenCount: 1_000,
            outputTokenCount: 200
        ),
        Message(
            conversationID: conversationID,
            role: .assistant,
            content: "second",
            inputTokenCount: 500,
            outputTokenCount: 100
        ),
    ]

    let stats = TokenUsageStats.compute(messages: messages)

    #expect(stats.inputTokens == 1_500)
    #expect(stats.outputTokens == 300)
    #expect(stats.totalTokens == 1_800)
    #expect(stats.requestCount == 2)
    #expect(!stats.isEmpty)
}

@Test func tokenUsagePrefersCacheTotalInputTokensOverRawInput() {
    // 缓存型端点的 inputTokenCount 只表示未命中缓存的部分，
    // 真实总输入由 cacheTotalInputTokenCount 给出。
    let message = Message(
        conversationID: UUID(),
        role: .assistant,
        content: "cached",
        inputTokenCount: 100,
        outputTokenCount: 50,
        cachedInputTokenCount: 900,
        cacheTotalInputTokenCount: 1_000
    )

    let stats = TokenUsageStats.compute(messages: [message])

    #expect(stats.inputTokens == 1_000)
    #expect(stats.outputTokens == 50)
    #expect(stats.totalTokens == 1_050)
}

@Test func tokenUsageIgnoresNonAssistantMessages() {
    let conversationID = UUID()
    let messages = [
        Message(
            conversationID: conversationID,
            role: .user,
            content: "hi",
            inputTokenCount: 800
        ),
        Message(
            conversationID: conversationID,
            role: .tool,
            content: "result",
            outputTokenCount: 300
        ),
        Message(
            conversationID: conversationID,
            role: .assistant,
            content: "ok",
            inputTokenCount: 400,
            outputTokenCount: 100
        ),
    ]

    let stats = TokenUsageStats.compute(messages: messages)

    #expect(stats.inputTokens == 400)
    #expect(stats.outputTokens == 100)
    #expect(stats.requestCount == 1)
}

@Test func tokenUsageSkipsResponsesWithoutReportedUsage() {
    // 供应商未上报 usage 时既没有输入也没有输出，
    // 不应被算成一次请求。
    let message = Message(
        conversationID: UUID(),
        role: .assistant,
        content: "no usage"
    )

    let stats = TokenUsageStats.compute(messages: [message])

    #expect(stats.isEmpty)
    #expect(stats.requestCount == 0)
    #expect(stats.totalTokens == 0)
}

@Test func tokenUsageEmptyStatsHaveZeroTotals() {
    #expect(TokenUsageStats.empty.isEmpty)
    #expect(TokenUsageStats.empty.totalTokens == 0)
    #expect(TokenUsageStats.compute(messages: []) == .empty)
}

// MARK: - 紧凑格式

@Test func tokenCountFormatterKeepsSmallValuesVerbatim() {
    #expect(TokenCountFormatter.compact(0) == "0")
    #expect(TokenCountFormatter.compact(999) == "999")
}

@Test func tokenCountFormatterUsesUnitsAndPromotesAcrossMagnitudes() {
    #expect(TokenCountFormatter.compact(1_000) == "1K")
    #expect(TokenCountFormatter.compact(1_500) == "1.5K")
    #expect(TokenCountFormatter.compact(43_982_407) == "44M")
    #expect(TokenCountFormatter.compact(999_999) == "1M")
}

// MARK: - 状态转发

@Test @MainActor func toolbarStateForwardsTypedEvents() {
    let state = TokenUsageToolbarState()
    let conversationID = UUID()
    var events: [TokenUsageToolbarState.Event] = []
    let handle = state.addObserver { events.append($0) }

    state.setSelectedConversationID(conversationID)
    state.markMessagesChanged(conversationID: conversationID)

    #expect(events.count == 2)
    handle.cancel()
    state.markMessagesChanged(conversationID: conversationID)
    #expect(events.count == 2)
}

@Test @MainActor func toolbarStateDoesNotNotifyWhenSelectionIsUnchanged() {
    let state = TokenUsageToolbarState()
    let id = UUID()
    var events: [TokenUsageToolbarState.Event] = []
    let handle = state.addObserver { events.append($0) }

    state.setSelectedConversationID(id)
    state.setSelectedConversationID(id)
    #expect(events.count == 1)

    state.setSelectedConversationID(nil)
    #expect(events.count == 2)
    handle.cancel()
}
