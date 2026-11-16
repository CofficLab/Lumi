import Foundation
import ProviderMessage
import Testing
@testable import PluginConversationSpeed

/// 「弹窗关闭时仍重建整段趋势历史」的回归测试（#1226）。
///
/// 速度工具栏常驻可见，但趋势历史只在弹窗里展示。此前每次选择 / 插入刷新
/// 都会无条件执行 `SpeedSample.samples`（filter + sort + compactMap，O(M log M)），
/// 长会话里每条消息都在主线程重排整段历史，造成卡顿。
///
/// 修复：工具栏数值（cachedTPS / requestCount）始终即时刷新；趋势历史只在
/// 弹窗打开时重建，关闭时清空。打开弹窗用最近一次快照即时补建，无需等待新事件。

@Test @MainActor func closedPopoverKeepsToolbarFreshWithoutBuildingHistory() {
    let conversationID = UUID()
    let first = speedPopoverMessage(conversationID: conversationID, outputTokens: 120, durationMs: 6_000)
    let second = speedPopoverMessage(conversationID: conversationID, outputTokens: 60, durationMs: 3_000)
    let viewModel = ConversationSpeedViewModel()

    // 弹窗关闭：工具栏数值照常更新，但历史保持为空（不触发排序）。
    viewModel.selectConversation(conversationID, messages: [first])
    #expect(viewModel.cachedTPS == 20)
    #expect(viewModel.requestCount == 1)
    #expect(viewModel.speedHistory.isEmpty)

    viewModel.refresh(conversationID: conversationID, messages: [first, second])
    #expect(viewModel.cachedTPS == 20)
    #expect(viewModel.requestCount == 2)
    #expect(viewModel.speedHistory.isEmpty, "弹窗关闭时不应重建趋势历史")

    // 打开弹窗：用最近快照即时补建历史，无需新的选择 / 插入事件。
    viewModel.setPopoverPresented(true)
    #expect(viewModel.speedHistory.count == 2)
}

@Test @MainActor func openingPopoverRebuildsHistoryFromLatestSnapshot() {
    let conversationID = UUID()
    let message = speedPopoverMessage(conversationID: conversationID, outputTokens: 80, durationMs: 4_000)
    let viewModel = ConversationSpeedViewModel()

    viewModel.selectConversation(conversationID, messages: [message])
    #expect(viewModel.speedHistory.isEmpty)

    viewModel.setPopoverPresented(true)
    #expect(viewModel.speedHistory.map(\.id) == [message.id])
}

@Test @MainActor func closingPopoverClearsHistoryButKeepsToolbarValue() {
    let conversationID = UUID()
    let message = speedPopoverMessage(conversationID: conversationID, outputTokens: 120, durationMs: 6_000)
    let viewModel = ConversationSpeedViewModel()

    viewModel.selectConversation(conversationID, messages: [message])
    viewModel.setPopoverPresented(true)
    #expect(viewModel.speedHistory.count == 1)

    viewModel.setPopoverPresented(false)
    #expect(viewModel.speedHistory.isEmpty)
    // 工具栏数值不随弹窗关闭而丢失。
    #expect(viewModel.cachedTPS == 20)
    #expect(viewModel.requestCount == 1)
}

@Test @MainActor func popoverOpenStillTracksNewInsertions() {
    let conversationID = UUID()
    let first = speedPopoverMessage(conversationID: conversationID, outputTokens: 120, durationMs: 6_000)
    let second = speedPopoverMessage(conversationID: conversationID, outputTokens: 60, durationMs: 3_000)
    let viewModel = ConversationSpeedViewModel()

    viewModel.selectConversation(conversationID, messages: [first])
    viewModel.setPopoverPresented(true)
    #expect(viewModel.speedHistory.count == 1)

    // 弹窗打开期间，新插入必须照常进入历史。
    viewModel.refresh(conversationID: conversationID, messages: [first, second])
    #expect(viewModel.speedHistory.count == 2)
    #expect(viewModel.cachedTPS == 20)
}

private func speedPopoverMessage(conversationID: UUID, outputTokens: Int, durationMs: Double) -> Message {
    Message(
        conversationID: conversationID,
        role: .assistant,
        content: "response",
        outputTokenCount: outputTokens,
        streamingDurationMs: durationMs
    )
}