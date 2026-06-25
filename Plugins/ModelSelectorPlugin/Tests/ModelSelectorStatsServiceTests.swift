import Foundation
import LumiCoreKit
import Testing
@testable import ModelSelectorPlugin

@Test func messagePerformanceMetadataComputesTPS() {
    let message = LumiChatMessage(
        conversationID: UUID(),
        role: .assistant,
        content: "hello",
        providerID: "openai",
        modelName: "gpt-4",
        metadata: LumiMessageTokenMetadata.metadata(inputTokens: 10, outputTokens: 100)
            .merging(
                LumiMessagePerformanceMetadata.metadata(
                    latencyMs: 5_000,
                    timeToFirstTokenMs: 800,
                    streamingDurationMs: 2_000
                )
            ) { _, new in new }
    )

    #expect(message.tokensPerSecond == 50)
}

@Test func modelSelectorStatsServiceAggregatesTPS() {
    let provider = LumiLLMProviderInfo(
        id: "openai",
        displayName: "OpenAI",
        description: "Test",
        defaultModel: "gpt-fast",
        availableModels: ["gpt-fast", "gpt-slow"],
        websiteURL: URL(string: "https://example.com")!
    )

    let messages = [
        LumiChatMessage(
            conversationID: UUID(),
            role: .assistant,
            content: "fast",
            providerID: "openai",
            modelName: "gpt-fast",
            metadata: LumiMessageTokenMetadata.metadata(inputTokens: 1, outputTokens: 100)
                .merging(
                    LumiMessagePerformanceMetadata.metadata(
                        latencyMs: 3_000,
                        timeToFirstTokenMs: 500,
                        streamingDurationMs: 1_000
                    )
                ) { _, new in new }
        ),
        LumiChatMessage(
            conversationID: UUID(),
            role: .assistant,
            content: "slow",
            providerID: "openai",
            modelName: "gpt-slow",
            metadata: LumiMessageTokenMetadata.metadata(inputTokens: 1, outputTokens: 50)
                .merging(
                    LumiMessagePerformanceMetadata.metadata(
                        latencyMs: 6_000,
                        timeToFirstTokenMs: 1_000,
                        streamingDurationMs: 5_000
                    )
                ) { _, new in new }
        ),
    ]

    let snapshot = ModelSelectorStatsService.buildSnapshot(messages: messages, providers: [provider])

    #expect(snapshot.detailedStats["openai|gpt-fast"]?.avgTPS == 100)
    #expect(snapshot.detailedStats["openai|gpt-slow"]?.avgTPS == 10)
    #expect(snapshot.fastModels.first?.model == "gpt-fast")
    #expect(snapshot.fastModels.first?.avgTPS == 100)
}
