import Foundation
import Testing

@testable import ProviderMessage

/// #1158：压缩事件「节省 / 消耗 / 净收益」核算的纯元数据逻辑。
@MainActor
struct MessageTimelineCompactionAccountingTests {

    private func compactionMessage(_ metadata: [String: String]) -> Message {
        var merged = metadata
        merged[MessageTimelineEvent.metadataKey] = MessageTimelineEvent.contextCompaction
        merged[MessageTimelineEvent.actualContextCompactionKey] = MessageTimelineEvent.actualContextCompactionValue
        return Message(
            conversationID: UUID(),
            role: .system,
            content: "对话已压缩",
            metadata: merged
        )
    }

    @Test("节省 = 压缩前 − 压缩后")
    func savedTokensIsOriginalMinusCompacted() {
        let message = compactionMessage([
            MessageTimelineEvent.contextCompactionOriginalEstimateKey: "10000",
            MessageTimelineEvent.contextCompactionCompactedEstimateKey: "3000",
        ])
        #expect(MessageTimelineEvent.compactionSavedTokens(for: message) == 7000)
    }

    @Test("净收益 = 节省 − 摘要消耗")
    func netTokensIsSavedMinusSpent() {
        let message = compactionMessage([
            MessageTimelineEvent.contextCompactionOriginalEstimateKey: "10000",
            MessageTimelineEvent.contextCompactionCompactedEstimateKey: "3000",
            MessageTimelineEvent.contextCompactionSpentTokensKey: "1500",
            MessageTimelineEvent.contextCompactionSpentIsEstimatedKey: "false",
        ])
        #expect(MessageTimelineEvent.compactionSpentTokens(for: message) == 1500)
        #expect(MessageTimelineEvent.compactionSpentIsEstimated(for: message) == false)
        #expect(MessageTimelineEvent.compactionNetTokens(for: message) == 5500)
    }

    @Test("消耗缺失时净收益为 nil，而不是把消耗当零")
    func netTokensNilWhenSpentMissing() {
        let message = compactionMessage([
            MessageTimelineEvent.contextCompactionOriginalEstimateKey: "10000",
            MessageTimelineEvent.contextCompactionCompactedEstimateKey: "3000",
        ])
        #expect(MessageTimelineEvent.compactionSpentTokens(for: message) == nil)
        #expect(MessageTimelineEvent.compactionNetTokens(for: message) == nil)
    }

    @Test("估算口径标记被正确读取")
    func estimatedFlagReadFromMetadata() {
        let message = compactionMessage([
            MessageTimelineEvent.contextCompactionSpentTokensKey: "800",
            MessageTimelineEvent.contextCompactionSpentIsEstimatedKey: "true",
        ])
        #expect(MessageTimelineEvent.compactionSpentIsEstimated(for: message))
        #expect(MessageTimelineEvent.compactionSpentTokens(for: message) == 800)
    }

    @Test("节省任一端缺失时为 nil")
    func savedTokensNilWhenEitherEndMissing() {
        let message = compactionMessage([
            MessageTimelineEvent.contextCompactionOriginalEstimateKey: "10000",
        ])
        #expect(MessageTimelineEvent.compactionSavedTokens(for: message) == nil)
    }
}