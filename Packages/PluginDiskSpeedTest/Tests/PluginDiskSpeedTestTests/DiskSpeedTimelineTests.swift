import Foundation
import ProviderMessage
import Testing
@testable import PluginDiskSpeedTest

@Suite("DiskSpeedTimeline")
struct DiskSpeedTimelineTests {

    @Test("payload survives the content round trip")
    func payloadRoundTripsThroughContent() {
        let original = DiskSpeedPayload(
            phase: .finished,
            readBytesPerSecond: 1_200_000_000,
            writeBytesPerSecond: 900_000_000,
            readBytes: 256 * 1024 * 1024,
            writeBytes: 256 * 1024 * 1024
        )

        let message = DiskSpeedTimeline.message(
            conversationID: UUID(),
            turnID: nil,
            payload: original
        )

        let decoded = DiskSpeedTimeline.decodePayload(from: message.content)
        #expect(decoded == original)
    }

    @Test("message is marked as a disk speed timeline event")
    func messageIsMarkedAsTimelineEvent() {
        let message = DiskSpeedTimeline.message(
            conversationID: UUID(),
            turnID: nil,
            payload: .running(directory: "/tmp")
        )

        #expect(message.renderKind == MessageTimelineEvent.diskSpeedRenderKind)
        #expect(message.preferredRendererID == DiskSpeedTimeline.rendererID)
        #expect(MessageTimelineEvent.isDiskSpeed(message))
    }

    /// 关键回归：测速卡片是纯界面产物，绝不能进入后续 LLM 上下文。
    ///
    /// 若 `isTimelineEvent` 漏掉了这一类型，卡片 JSON 会被当成对话历史
    /// 发给模型，既浪费 token 又让模型看到看不懂的内容。
    @Test("card is excluded from the LLM context")
    func cardIsExcludedFromLLMContext() {
        let message = DiskSpeedTimeline.message(
            conversationID: UUID(),
            turnID: nil,
            payload: .finished(
                readBytesPerSecond: 1_000_000_000,
                writeBytesPerSecond: 800_000_000
            )
        )

        #expect(MessageTimelineEvent.isTimelineEvent(message))
    }

    @Test("corrupted content degrades to nil instead of crashing")
    func corruptedContentDegradesToNil() {
        #expect(DiskSpeedTimeline.decodePayload(from: "not json at all") == nil)
        #expect(DiskSpeedTimeline.decodePayload(from: "") == nil)
    }

    @Test("summary text stays readable for every phase")
    func summaryTextStaysReadable() {
        #expect(DiskSpeedTimeline.summaryText(for: .running(directory: "/tmp")).contains("Testing"))
        #expect(
            DiskSpeedTimeline.summaryText(for: .failed(directory: "/tmp", reason: "boom"))
                .contains("boom")
        )
        #expect(
            DiskSpeedTimeline.summaryText(
                for: DiskSpeedPayload(
                    phase: .finished,
                    readBytesPerSecond: 1_000_000_000,
                    writeBytesPerSecond: 1_000_000_000
                )
            ).contains("GB/s")
        )
    }
}
