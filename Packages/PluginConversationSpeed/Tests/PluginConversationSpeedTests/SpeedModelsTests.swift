import Foundation
import ProviderMessage
import Testing
@testable import PluginConversationSpeed

@Test func speedDurationUsesTheLongerAvailableRequestDuration() {
    let message = speedMessage(streamingDurationMs: 1_200, latencyMs: 2_500)
    #expect(message.speedDurationMs == 2_500)
    #expect(message.speedTokensPerSecond == 48)
}

@Test func speedDurationFallsBackToEitherPositiveMeasurement() {
    #expect(speedMessage(streamingDurationMs: 1_250).speedDurationMs == 1_250)
    #expect(speedMessage(latencyMs: 2_500).speedDurationMs == 2_500)
    #expect(speedMessage(streamingDurationMs: 0, latencyMs: 2_500).speedDurationMs == 2_500)
    #expect(speedMessage(streamingDurationMs: -1, latencyMs: 0).speedDurationMs == nil)
    #expect(speedMessage().speedDurationMs == nil)
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
    createdAt: Date = Date(timeIntervalSince1970: 1)
) -> Message {
    Message(
        conversationID: conversationID,
        role: role,
        content: "response",
        createdAt: createdAt,
        outputTokenCount: outputTokens,
        latencyMs: latencyMs,
        streamingDurationMs: streamingDurationMs
    )
}
