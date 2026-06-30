import Foundation
import Testing
import LumiCoreKit

@Test func contextUsageUsesAssistantInputTokensAndFollowingUserEstimates() {
    let conversationID = UUID()
    let messages = [
        LumiChatMessage(
            conversationID: conversationID,
            role: .user,
            content: String(repeating: "a", count: 400)
        ),
        LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "Reply",
            metadata: LumiMessageTokenMetadata.metadata(inputTokens: 12_000, outputTokens: 500)
        ),
        LumiChatMessage(
            conversationID: conversationID,
            role: .user,
            content: String(repeating: "b", count: 400)
        ),
    ]

    let anthropicProvider = LumiLLMProviderInfo(
        id: "anthropic",
        displayName: "Anthropic",
        defaultModel: "claude-sonnet-4-20250514",
        availableModels: ["claude-sonnet-4-20250514"],
        contextWindowSizes: ["claude-sonnet-4-20250514": 200_000],
        websiteURL: URL(string: "https://example.com")!
    )

    let usage = LumiConversationContextCalculator.usage(
        messages: messages,
        providerID: "anthropic",
        modelName: "claude-sonnet-4-20250514",
        providerInfos: [anthropicProvider]
    )

    #expect(usage.currentTokens == 12_100)
    #expect(usage.limit == 200_000)
    #expect(usage.label == "12.1k/200.0k")
}

@Test func contextUsagePrefersProviderSpecificLimit() {
    let provider = LumiLLMProviderInfo(
        id: "openai",
        displayName: "OpenAI",
        defaultModel: "gpt-4o",
        availableModels: ["gpt-4o"],
        contextWindowSizes: ["gpt-4o": 128_000],
        websiteURL: URL(string: "https://example.com")!
    )

    let usage = LumiConversationContextCalculator.usage(
        messages: [
            LumiChatMessage(
                conversationID: UUID(),
                role: .assistant,
                content: "Hi",
                metadata: LumiMessageTokenMetadata.metadata(inputTokens: 1_000, outputTokens: 100)
            )
        ],
        providerID: "openai",
        modelName: "gpt-4o",
        providerInfos: [provider]
    )

    #expect(usage.limit == 128_000)
    #expect(usage.label == "1.0k/128.0k")
}

@Test func contextUsageIsZeroBeforeFirstAssistantReply() {
    let usage = LumiConversationContextCalculator.usage(
        messages: [
            LumiChatMessage(conversationID: UUID(), role: .user, content: "Hello")
        ],
        providerID: "anthropic",
        modelName: "claude-sonnet-4-20250514",
        providerInfos: []
    )

    #expect(usage.currentTokens == 0)
}
