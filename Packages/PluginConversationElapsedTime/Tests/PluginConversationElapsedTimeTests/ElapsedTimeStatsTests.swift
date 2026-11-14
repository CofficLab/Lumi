import Foundation
import ProviderMessage
import Testing
@testable import PluginConversationElapsedTime

// MARK: - 用时聚合

@Test func elapsedTimeSumsLatencyAcrossAssistantMessages() {
    let conversationID = UUID()
    let messages = [
        Message(
            conversationID: conversationID,
            role: .assistant,
            content: "first",
            latencyMs: 600_000,
            timeToFirstTokenMs: 30_000,
            streamingDurationMs: 570_000
        ),
        Message(
            conversationID: conversationID,
            role: .assistant,
            content: "second",
            latencyMs: 600_000,
            timeToFirstTokenMs: 20_000,
            streamingDurationMs: 580_000
        ),
    ]

    let stats = ElapsedTimeStats.compute(messages: messages)

    #expect(stats.totalLatencyMs == 1_200_000)
    #expect(stats.totalSeconds == 1_200)
    #expect(stats.requestCount == 2)
    #expect(stats.firstTokenWaitMs == 50_000)
    #expect(stats.generationMs == 1_150_000)
    #expect(!stats.isEmpty)
}

@Test func elapsedTimeExcludesIdleGapsBetweenTurns() {
    // 两次各跑 10 分钟，中间空闲 20 分钟：空闲不产生消息，因此不计入。
    let conversationID = UUID()
    let messages = [
        Message(
            conversationID: conversationID,
            role: .assistant,
            content: "run 1",
            latencyMs: 600_000
        ),
        Message(
            conversationID: conversationID,
            role: .user,
            content: "20 minutes later"
        ),
        Message(
            conversationID: conversationID,
            role: .assistant,
            content: "run 2",
            latencyMs: 600_000
        ),
    ]

    let stats = ElapsedTimeStats.compute(messages: messages)

    #expect(stats.totalSeconds == 1_200)
    #expect(stats.requestCount == 2)
}

@Test func elapsedTimeIgnoresNonAssistantMessages() {
    let conversationID = UUID()
    let messages = [
        Message(
            conversationID: conversationID,
            role: .user,
            content: "hi",
            latencyMs: 5_000
        ),
        Message(
            conversationID: conversationID,
            role: .tool,
            content: "result",
            latencyMs: 5_000
        ),
        Message(
            conversationID: conversationID,
            role: .assistant,
            content: "ok",
            latencyMs: 5_000
        ),
    ]

    let stats = ElapsedTimeStats.compute(messages: messages)

    #expect(stats.totalLatencyMs == 5_000)
    #expect(stats.requestCount == 1)
}

@Test func elapsedTimeSkipsMessagesWithoutTiming() {
    // 老消息与失败后落下的空响应都没有计时数据，不该被算成一次请求。
    let conversationID = UUID()
    let messages = [
        Message(conversationID: conversationID, role: .assistant, content: "no timing"),
        Message(conversationID: conversationID, role: .assistant, content: "zero", latencyMs: 0),
    ]

    let stats = ElapsedTimeStats.compute(messages: messages)

    #expect(stats.isEmpty)
    #expect(stats.requestCount == 0)
    #expect(stats.totalSeconds == 0)
}

@Test func elapsedTimeEmptyStatsHaveZeroTotals() {
    #expect(ElapsedTimeStats.empty.isEmpty)
    #expect(ElapsedTimeStats.empty.totalSeconds == 0)
    #expect(ElapsedTimeStats.compute(messages: []) == .empty)
}

// MARK: - 紧凑格式

@Test func elapsedTimeFormatterUsesSecondsMinutesAndHours() {
    #expect(ElapsedTimeFormatter.compact(0) == "0s")
    #expect(ElapsedTimeFormatter.compact(45) == "45s")
    #expect(ElapsedTimeFormatter.compact(59.4) == "59s")
    #expect(ElapsedTimeFormatter.compact(60) == "1m")
    #expect(ElapsedTimeFormatter.compact(1_380) == "23m")
    #expect(ElapsedTimeFormatter.compact(4_320) == "1.2h")
}

@Test func elapsedTimeFormatterDropsTrailingZeroAndRoundsLargeHours() {
    #expect(ElapsedTimeFormatter.compact(3_600) == "1h")
    #expect(ElapsedTimeFormatter.compact(93_600) == "26h")
}

// MARK: - 状态转发

@Test @MainActor func toolbarStateForwardsTypedEvents() {
    let state = ElapsedTimeToolbarState()
    let conversationID = UUID()
    var events: [ElapsedTimeToolbarState.Event] = []
    let handle = state.addObserver { events.append($0) }

    state.setSelectedConversationID(conversationID)
    state.markMessagesChanged(conversationID: conversationID)

    #expect(events.count == 2)
    handle.cancel()
    state.markMessagesChanged(conversationID: conversationID)
    #expect(events.count == 2)
}

@Test @MainActor func toolbarStateDoesNotNotifyWhenSelectionIsUnchanged() {
    let state = ElapsedTimeToolbarState()
    let id = UUID()
    var events: [ElapsedTimeToolbarState.Event] = []
    let handle = state.addObserver { events.append($0) }

    state.setSelectedConversationID(id)
    state.setSelectedConversationID(id)
    #expect(events.count == 1)

    state.setSelectedConversationID(nil)
    #expect(events.count == 2)
    handle.cancel()
}
