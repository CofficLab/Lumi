import Testing
@testable import LumiLLMProviderSupport

struct AvailabilityTests {
    @Test
    func pingTokenLimitOverridesProviderDefault() {
        var body: [String: Any] = [
            "model": "glm-4.7",
            "max_tokens": 8192,
            "messages": [["role": "user", "content": "ping"]],
        ]

        LumiLLMProviderAvailabilitySupport.applyPingTokenLimit(to: &body)

        #expect(body["max_tokens"] as? Int == 1)
    }

    @Test
    func pingTokenLimitSetsMissingMaxTokens() {
        var body: [String: Any] = [
            "model": "gpt-4",
            "messages": [["role": "user", "content": "ping"]],
            "stream": false,
        ]

        LumiLLMProviderAvailabilitySupport.applyPingTokenLimit(to: &body)

        #expect(body["max_tokens"] as? Int == 1)
    }
}
