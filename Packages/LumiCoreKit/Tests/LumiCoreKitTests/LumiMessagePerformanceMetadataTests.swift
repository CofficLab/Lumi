import Foundation
import Testing
@testable import LumiCoreKit

@Test func performanceMetadataComputesTPSFromOutputTokens() {
    let message = LumiChatMessage(
        conversationID: UUID(),
        role: .assistant,
        content: "ok",
        metadata: LumiMessageTokenMetadata.metadata(inputTokens: 5, outputTokens: 40)
            .merging(
                LumiMessagePerformanceMetadata.metadata(
                    latencyMs: 2_000,
                    timeToFirstTokenMs: 300,
                    streamingDurationMs: 4_000
                )
            ) { _, new in new }
    )

    #expect(message.tokensPerSecond == 10)
}

@Test func performanceMetadataReturnsNilTPSWithoutStreamingDuration() {
    let message = LumiChatMessage(
        conversationID: UUID(),
        role: .assistant,
        content: "ok",
        metadata: LumiMessageTokenMetadata.metadata(inputTokens: 5, outputTokens: 40)
    )

    #expect(message.tokensPerSecond == nil)
}
