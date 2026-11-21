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

    @Test("真实压缩后本地估算从压缩后基线重新累计（#609）")
    func estimateRestartsFromCompactedBaselineAfterActualCompaction() {
        let base = Date(timeIntervalSince1970: 5_500)
        let preCompactionUser = Message(
            conversationID: conversationID,
            role: .user,
            content: String(repeating: "a", count: 300),
            createdAt: base
        )
        let compaction = Message(
            conversationID: conversationID,
            role: .system,
            content: "对话已压缩",
            createdAt: base.addingTimeInterval(2),
            metadata: [
                MessageTimelineEvent.metadataKey: MessageTimelineEvent.contextCompaction,
                MessageTimelineEvent.actualContextCompactionKey: MessageTimelineEvent.actualContextCompactionValue,
                MessageTimelineEvent.contextCompactionReasonKey: MessageTimelineEvent.ContextCompactionReason.hardThreshold.rawValue,
                MessageTimelineEvent.contextCompactionOriginalEstimateKey: "104000",
                MessageTimelineEvent.contextCompactionCompactedEstimateKey: "21000",
            ]
        )
        let postCompactionUser = Message(
            conversationID: conversationID,
            role: .user,
            content: String(repeating: "b", count: 100),
            createdAt: base.addingTimeInterval(3)
        )
        let messages = [
            preCompactionUser,
            assistantMessage("回复一", inputTokens: nil, at: base.addingTimeInterval(1)),
            compaction,
            postCompactionUser,
            assistantMessage("回复二", inputTokens: nil, at: base.addingTimeInterval(4)),
        ]

        let history = ContextUsageHistory.build(from: messages)

        #expect(history.compactionMarkers.count == 1)
        #expect(history.samples.count == 2)
        // 压缩前仍是旧口径：完整历史的本地累计。
        #expect(history.samples[0].isEstimated)
        #expect(history.samples[0].tokens == LLMContextTokenEstimator.estimate(message: preCompactionUser))
        // 压缩后从事件记录的压缩后估算出发，只累加压缩后的新消息；
        // 采样取在 assistant 自身估算加入之前，故不含回复二的估算。
        let expectedPost = 21_000
            + LLMContextTokenEstimator.estimate(message: postCompactionUser)
        #expect(history.samples[1].isEstimated)
        #expect(history.samples[1].tokens == expectedPost)
    }

    @Test("缺少压缩后估算的旧压缩事件保持旧累计口径（#609 护栏）")
    func legacyCompactionWithoutEstimateMetadataKeepsCumulative() {
        let base = Date(timeIntervalSince1970: 5_600)
        let user = Message(
            conversationID: conversationID,
            role: .user,
            content: String(repeating: "a", count: 300),
            createdAt: base
        )
        let compaction = Message(
            conversationID: conversationID,
            role: .system,
            content: "对话已压缩",
            createdAt: base.addingTimeInterval(2),
            metadata: [
                MessageTimelineEvent.metadataKey: MessageTimelineEvent.contextCompaction,
                MessageTimelineEvent.actualContextCompactionKey: MessageTimelineEvent.actualContextCompactionValue,
            ]
        )
        let messages = [
            user,
            assistantMessage("回复一", inputTokens: nil, at: base.addingTimeInterval(1)),
            compaction,
            assistantMessage("回复二", inputTokens: nil, at: base.addingTimeInterval(3)),
        ]

        let history = ContextUsageHistory.build(from: messages)

        // metadata 缺失时不得把累计清零：仍沿用压缩前的完整累计。
        #expect(history.samples.count == 2)
        #expect(history.samples[0].tokens == LLMContextTokenEstimator.estimate(message: user))
        let expectedPost = LLMContextTokenEstimator.estimate(message: user)
            + LLMContextTokenEstimator.estimate(message: messages[1])
        #expect(history.samples[1].tokens == expectedPost)
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

    /// 模型切换时间线消息与真实请求的过滤规则一致：不采样也不累计（#855）。
    @Test("模型切换等时间线消息不计入估算（回归 #855）")
    func modelSwitchTimelineEventExcludedFromEstimate() {
        let base = Date(timeIntervalSince1970: 9_000)
        let user = Message(
            conversationID: conversationID,
            role: .user,
            content: String(repeating: "a", count: 300),
            createdAt: base
        )
        let modelSwitch = Message(
            conversationID: conversationID,
            role: .system,
            content: "已从 A 切换到 B " + String(repeating: "m", count: 900),
            createdAt: base.addingTimeInterval(1),
            metadata: [
                MessageTimelineEvent.metadataKey: MessageTimelineEvent.modelSwitched,
            ],
            renderKind: MessageTimelineEvent.modelSwitchedRenderKind
        )
        let messages = [
            user,
            modelSwitch,
            assistantMessage("回复", inputTokens: nil, at: base.addingTimeInterval(2)),
        ]

        let history = ContextUsageHistory.build(from: messages)

        let expected = LLMContextTokenEstimator.estimate(message: user)
        #expect(history.samples.count == 1)
        #expect(history.samples[0].isEstimated)
        #expect(history.samples[0].tokens == expected, "时间线消息正文不得计入输入估算")
    }
}
