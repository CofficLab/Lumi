import Foundation
import ProviderLLMContext
import ProviderMessage
import Testing

@testable import PluginLLMContext

struct ContextUsageHistoryTests {
    private let conversationID = UUID()

    private func assistantMessage(
        _ content: String,
        inputTokens: Int?,
        at date: Date,
        metadata: [String: String] = [:]
    ) -> Message {
        Message(
            conversationID: conversationID,
            role: .assistant,
            content: content,
            createdAt: date,
            metadata: metadata,
            inputTokenCount: inputTokens
        )
    }

    @Test("没有请求时历史为空")
    func emptyHistory() {
        let history = ContextUsageHistory.build(from: [])
        #expect(history.samples.isEmpty)
        #expect(history.latestTokens == nil)
        #expect(history.peakTokens == nil)
        #expect(history.minimumTokens == nil)
        #expect(history.hasEstimatedSamples == false)
    }

    @Test("采样点取服务端上报的 inputTokenCount")
    func samplesUseReportedInputTokens() {
        let base = Date(timeIntervalSince1970: 1_000)
        let messages = [
            Message(conversationID: conversationID, role: .user, content: "你好", createdAt: base),
            assistantMessage("回复一", inputTokens: 1_200, at: base.addingTimeInterval(1)),
            assistantMessage("回复二", inputTokens: 3_400, at: base.addingTimeInterval(2)),
        ]

        let history = ContextUsageHistory.build(from: messages)

        #expect(history.samples.map(\.tokens) == [1_200, 3_400])
        #expect(history.samples.map(\.isEstimated) == [false, false])
        #expect(history.samples.map(\.index) == [0, 1])
        #expect(history.latestTokens == 3_400)
        #expect(history.peakTokens == 3_400)
        #expect(history.minimumTokens == 1_200)
        #expect(history.hasEstimatedSamples == false)
    }

    @Test("assistant 自身的输出不计入下一轮输入")
    func assistantOutputExcludedFromInput() {
        let base = Date(timeIntervalSince1970: 2_000)
        let messages = [
            Message(
                conversationID: conversationID,
                role: .user,
                content: String(repeating: "x", count: 300),
                createdAt: base
            ),
            assistantMessage(
                "很长的一段回复内容",
                inputTokens: 100,
                at: base.addingTimeInterval(1)
            ),
        ]

        let history = ContextUsageHistory.build(from: messages)

        // 只有一条采样，且用的是服务端上报值，而不是把 assistant 输出累加进去。
        #expect(history.samples.count == 1)
        #expect(history.samples[0].tokens == 100)
    }

    @Test("供应商未上报 usage 时用本地累计估算")
    func fallsBackToLocalEstimate() {
        let base = Date(timeIntervalSince1970: 3_000)
        let user = Message(
            conversationID: conversationID,
            role: .user,
            content: String(repeating: "a", count: 300),
            createdAt: base
        )
        let messages = [
            user,
            assistantMessage("回复", inputTokens: nil, at: base.addingTimeInterval(1)),
        ]

        let history = ContextUsageHistory.build(from: messages)

        let expected = LLMContextTokenEstimator.estimate(message: user)
        #expect(history.samples.count == 1)
        #expect(history.samples[0].isEstimated)
        #expect(history.samples[0].tokens == expected)
        #expect(history.hasEstimatedSamples)
    }

    @Test("无累计内容时不产生估算采样，避免零值点")
    func noSampleWhenNothingAccumulated() {
        let base = Date(timeIntervalSince1970: 4_000)
        let messages = [
            assistantMessage("凭空出现的回复", inputTokens: nil, at: base),
        ]

        let history = ContextUsageHistory.build(from: messages)

        #expect(history.samples.isEmpty)
    }

    @Test("真实的压缩事件只作为标记，不计入采样")
    func actualCompactionBecomesMarker() {
        let base = Date(timeIntervalSince1970: 5_000)
        let compaction = Message(
            conversationID: conversationID,
            role: .system,
            content: "对话已压缩",
            createdAt: base.addingTimeInterval(2),
            metadata: [
                MessageTimelineEvent.metadataKey: MessageTimelineEvent.contextCompaction,
                MessageTimelineEvent.actualContextCompactionKey: MessageTimelineEvent.actualContextCompactionValue,
                MessageTimelineEvent.contextCompactionReasonKey: MessageTimelineEvent.ContextCompactionReason.hardThreshold.rawValue,
            ]
        )
        let messages = [
            assistantMessage("回复一", inputTokens: 900, at: base),
            compaction,
            assistantMessage("回复二", inputTokens: 400, at: base.addingTimeInterval(3)),
        ]

        let history = ContextUsageHistory.build(from: messages)

        #expect(history.samples.map(\.tokens) == [900, 400])
        #expect(history.compactionMarkers.count == 1)
        #expect(history.compactionMarkers[0].reason == .hardThreshold)
        // 标记落在首个采样点之后。
        #expect(history.compactionMarkers[0].afterSampleIndex == 0)
    }

    @Test("后台预热事件不显示为压缩标记")
    func prewarmEventIsNotAMarker() {
        let base = Date(timeIntervalSince1970: 6_000)
        let prewarm = Message(
            conversationID: conversationID,
            role: .system,
            content: "对话已压缩",
            createdAt: base.addingTimeInterval(1),
            metadata: [
                MessageTimelineEvent.metadataKey: MessageTimelineEvent.contextCompaction,
            ]
        )
        let messages = [
            assistantMessage("回复", inputTokens: 500, at: base),
            prewarm,
        ]

        let history = ContextUsageHistory.build(from: messages)

        #expect(history.compactionMarkers.isEmpty)
    }

    @Test("错误与状态消息不计入累计 token")
    func nonLLMRolesExcluded() {
        let base = Date(timeIntervalSince1970: 7_000)
        let messages = [
            Message(
                conversationID: conversationID,
                role: .error,
                content: String(repeating: "e", count: 900),
                createdAt: base
            ),
            Message(
                conversationID: conversationID,
                role: .status,
                content: String(repeating: "s", count: 900),
                createdAt: base.addingTimeInterval(1)
            ),
            assistantMessage("回复", inputTokens: nil, at: base.addingTimeInterval(2)),
        ]

        let history = ContextUsageHistory.build(from: messages)

        #expect(history.samples.isEmpty)
    }

    @Test("采样点按时间排序，与消息插入顺序无关")
    func samplesAreChronologicallyOrdered() {
        let base = Date(timeIntervalSince1970: 8_000)
        let messages = [
            assistantMessage("较晚", inputTokens: 800, at: base.addingTimeInterval(10)),
            assistantMessage("较早", inputTokens: 200, at: base),
        ]

        let history = ContextUsageHistory.build(from: messages)

        #expect(history.samples.map(\.tokens) == [200, 800])
        #expect(history.samples.map(\.index) == [0, 1])
    }
}
