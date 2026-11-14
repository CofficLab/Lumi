import Foundation
import ProviderMessage
import Testing
@testable import PluginConversationSpeed

@Test func speedDurationPrefersStreamingGenerationTime() {
    // #237：streaming 与 latency 同时有效时取生成时长（1200），而非完整延迟（2500）。
    let message = speedMessage(streamingDurationMs: 1_200, latencyMs: 2_500)
    #expect(message.speedDurationMs == 1_200)
    #expect(message.speedTokensPerSecond == 100)
}

@Test func streamingSpeedExcludesTimeToFirstToken() {
    // #237：100 tokens，TTFT 2s，首 token 后生成 8s，完整延迟 10s。
    // 生成速度应为 100/8 = 12.5，而非 100/max(8,10) = 10。
    let message = speedMessage(
        outputTokens: 100,
        streamingDurationMs: 8_000,
        latencyMs: 10_000,
        timeToFirstTokenMs: 2_000
    )
    #expect(message.speedDurationMs == 8_000)
    #expect(message.speedTokensPerSecond == 12.5)
}

@Test func averageSpeedUsesStreamingDurationWhenBothPresent() {
    // #237：历史曲线/平均同样走 speedDurationMs，须用生成时长而非完整延迟。
    let messages = [
        speedMessage(outputTokens: 100, streamingDurationMs: 8_000, latencyMs: 10_000),
        speedMessage(outputTokens: 60, streamingDurationMs: 2_000, latencyMs: 5_000),
    ]
    let samples = SpeedSample.samples(from: messages)
    // 100/8 = 12.5，60/2 = 30 → 平均 21.25；误用完整延迟则为 (10 + 12)/2 = 11。
    #expect(SpeedSample.averageTokensPerSecond(from: samples) == 21.25)
}

@Test func speedDurationFallsBackToEitherPositiveMeasurement() {
    #expect(speedMessage(streamingDurationMs: 1_250).speedDurationMs == 1_250)
    #expect(speedMessage(latencyMs: 2_500).speedDurationMs == 2_500)
    #expect(speedMessage(streamingDurationMs: 0, latencyMs: 2_500).speedDurationMs == 2_500)
    #expect(speedMessage(streamingDurationMs: -1, latencyMs: 0).speedDurationMs == nil)
    #expect(speedMessage().speedDurationMs == nil)
}

@Test func legacyMetadataTimingRestoresHistoricalSpeedAndTTFT() {
    // #1029：旧版只把计时写进 metadata，强类型字段为空。
    let message = speedMessage(
        streamingDurationMs: nil,
        latencyMs: nil,
        metadata: [
            "latencyMs": "6000.0",
            "streamingDurationMs": "4000.0",
            "timeToFirstTokenMs": "2000.0",
        ]
    )

    #expect(message.speedDurationMs == 4_000)
    #expect(message.speedTokensPerSecond == 30)
    #expect(message.speedTimeToFirstTokenMs == 2_000)
}

@Test func typedTimingTakesPrecedenceOverLegacyMetadata() {
    let message = speedMessage(
        streamingDurationMs: 1_000,
        latencyMs: 2_000,
        timeToFirstTokenMs: 500,
        metadata: [
            "latencyMs": "9000.0",
            "timeToFirstTokenMs": "8000.0",
        ]
    )

    #expect(message.speedDurationMs == 1_000)
    #expect(message.speedTimeToFirstTokenMs == 500)
}

@Test func speedRequiresOutputTokensAndPositiveDuration() {
    #expect(speedMessage(outputTokens: nil).speedTokensPerSecond == nil)
    #expect(speedMessage(streamingDurationMs: nil).speedTokensPerSecond == nil)
    #expect(speedMessage(outputTokens: 0, streamingDurationMs: 1_000).speedTokensPerSecond == 0)
}

@Test func speedSamplesSortChronologicallyAndExcludeMessagesWithoutSpeedData() {
    let conversationID = UUID()
    let late = speedMessage(conversationID: conversationID, outputTokens: 60, streamingDurationMs: 2_000, createdAt: Date(timeIntervalSince1970: 20))
    let early = speedMessage(conversationID: conversationID, outputTokens: 90, streamingDurationMs: 3_000, createdAt: Date(timeIntervalSince1970: 10))
    let missing = speedMessage(conversationID: conversationID, outputTokens: nil, streamingDurationMs: 3_000)
    let userWithUnexpectedOutputMetadata = speedMessage(
        conversationID: conversationID,
        role: .user,
        outputTokens: 100,
        streamingDurationMs: 1_000
    )

    let samples = SpeedSample.samples(from: [late, missing, userWithUnexpectedOutputMetadata, early])

    #expect(samples.map(\.id) == [early.id, late.id])
    #expect(samples.map(\.index) == [0, 1])
    #expect(samples.map(\.tokensPerSecond) == [30, 30])
    #expect(samples.map(\.message.id) == [early.id, late.id])
}

@Test func averageSpeedIsNilForNoSamplesAndArithmeticMeanOtherwise() {
    let messages = [
        speedMessage(outputTokens: 20, streamingDurationMs: 1_000),
        speedMessage(outputTokens: 90, streamingDurationMs: 3_000),
    ]
    let samples = SpeedSample.samples(from: messages)

    #expect(SpeedSample.averageTokensPerSecond(from: []) == nil)
    #expect(SpeedSample.averageTokensPerSecond(from: samples) == 25)
}

@Test func unavailabilityReasonDistinguishesMissingMetrics() {
    #expect(SpeedUnavailability.reason(for: nil) == .waitingForResponse)
    #expect(SpeedUnavailability.reason(for: speedMessage(outputTokens: nil, streamingDurationMs: nil)) == .missingOutputTokensAndDuration)
    #expect(SpeedUnavailability.reason(for: speedMessage(outputTokens: nil, streamingDurationMs: 1_000)) == .missingOutputTokens)
    #expect(SpeedUnavailability.reason(for: speedMessage(outputTokens: 10, streamingDurationMs: nil)) == .missingDuration)
    #expect(SpeedUnavailability.reason(for: speedMessage(outputTokens: 10, streamingDurationMs: 1_000)) == .waitingForResponse)
}

@Test func everyUnavailabilityReasonHasLocalizedExplanation() {
    let reasons: [SpeedUnavailability] = [
        .noConversationSelected,
        .waitingForResponse,
        .missingOutputTokens,
        .missingDuration,
        .missingOutputTokensAndDuration,
    ]

    #expect(reasons.allSatisfy { !$0.localizedExplanation.isEmpty })
}

private func speedMessage(
    conversationID: UUID = UUID(),
    role: MessageRole = .assistant,
    outputTokens: Int? = 120,
    streamingDurationMs: Double? = nil,
    latencyMs: Double? = nil,
    timeToFirstTokenMs: Double? = nil,
    metadata: [String: String] = [:],
    createdAt: Date = Date(timeIntervalSince1970: 1)
) -> Message {
    Message(
        conversationID: conversationID,
        role: role,
        content: "response",
        createdAt: createdAt,
        metadata: metadata,
        outputTokenCount: outputTokens,
        latencyMs: latencyMs,
        timeToFirstTokenMs: timeToFirstTokenMs,
        streamingDurationMs: streamingDurationMs
    )
}
