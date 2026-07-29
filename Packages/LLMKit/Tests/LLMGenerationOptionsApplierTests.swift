import Foundation
import LLMKit
import Testing
@testable import LLMKit

@Suite("LLMGenerationOptionsApplier Tests")
struct LLMGenerationOptionsApplierTests {
    @Test("OpenAI applier maps temperature and max_tokens")
    func openAIBasic() {
        var body: [String: Any] = ["model": "gpt-4o"]
        let config = LLMConfig(model: "gpt-4o", providerId: "openai", temperature: 0.5, maxTokens: 1024)
        OpenAICompatibleGenerationOptionsApplier.apply(config: config, model: "gpt-4o", to: &body)
        #expect(body["temperature"] as? Double == 0.5)
        #expect(body["max_tokens"] as? Int == 1024)
    }

    @Test("OpenAI applier uses max_completion_tokens for o-series models")
    func openAIReasoningModel() {
        var body: [String: Any] = [:]
        let config = LLMConfig(model: "o3-mini", providerId: "openai", maxTokens: 2048)
        OpenAICompatibleGenerationOptionsApplier.apply(config: config, model: "o3-mini", to: &body)
        #expect(body["max_completion_tokens"] as? Int == 2048)
        #expect(body["max_tokens"] == nil)
    }

    @Test("OpenAI applier maps reasoning effort")
    func openAIReasoningEffort() {
        var body: [String: Any] = [:]
        let config = LLMConfig(model: "gpt-5", providerId: "openai", reasoningEffort: "high")
        OpenAICompatibleGenerationOptionsApplier.apply(config: config, model: "gpt-5", to: &body)
        #expect(body["reasoning_effort"] as? String == "high")
    }

    @Test("OpenAI applier ignores automatic reasoning effort")
    func openAIIgnoresAutomaticReasoningEffort() {
        var body: [String: Any] = [:]
        let config = LLMConfig(model: "gpt-5", providerId: "openai", reasoningEffort: "auto")
        OpenAICompatibleGenerationOptionsApplier.apply(config: config, model: "gpt-5", to: &body)
        #expect(body["reasoning_effort"] == nil)
    }

    @Test("Anthropic applier maps reasoning effort to thinking budget")
    func anthropicThinkingBudget() {
        var body: [String: Any] = ["max_tokens": 8192]
        let config = LLMConfig(model: "claude-sonnet-4", providerId: "anthropic", reasoningEffort: "medium")
        AnthropicCompatibleGenerationOptionsApplier.apply(
            config: config,
            model: "claude-sonnet-4",
            defaultMaxTokens: 8192,
            to: &body
        )
        let thinking = body["thinking"] as? [String: Any]
        #expect(thinking?["type"] as? String == "enabled")
        #expect(thinking?["budget_tokens"] as? Int == 4096)
    }

    @Test("Message preparer keeps system and drops status")
    func messagePreparer() {
        let messages = [
            ChatMessage(role: .system, content: "sys"),
            ChatMessage(role: .user, content: "hi"),
            ChatMessage(role: .status, content: "skip"),
        ]
        let prepared = LLMMessagePreparer.prepare(messages)
        #expect(prepared.count == 2)
        #expect(prepared.map(\.role) == [.system, .user])
    }
}
