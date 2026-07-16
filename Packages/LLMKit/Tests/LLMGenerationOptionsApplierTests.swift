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
