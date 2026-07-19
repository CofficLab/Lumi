import Foundation
import LumiKernel
import Testing
@testable import ModelSelectorPlugin

@Suite struct ModelSelectorStatusResolverTests {
    private let provider = LumiLLMProviderInfo(
        id: "stub",
        displayName: "Stub",
        defaultModel: "demo-model",
        availableModels: ["demo-model"],
        websiteURL: URL(string: "https://example.com")!
    )

    @Test func returnsProviderStatus() {
        let status = ModelSelectorStatusResolver.resolve(
            provider: provider,
            providerInstance: StubProvider()
        )

        #expect(status == LumiLLMProviderStatus(message: "custom status", level: .warning))
    }

    @Test func returnsNilWhenProviderUnavailable() {
        let status = ModelSelectorStatusResolver.resolve(
            provider: provider,
            providerInstance: nil
        )

        #expect(status == nil)
    }
}

private struct StubProvider: LumiLLMProvider {
    static let info = LumiLLMProviderInfo(
        id: "stub",
        displayName: "Stub",
        defaultModel: "demo-model",
        availableModels: ["demo-model"],
        websiteURL: URL(string: "https://example.com")!
    )

    func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        throw NSError(domain: "test", code: 1)
    }

    func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        .available
    }

    func providerStatus() -> LumiLLMProviderStatus? {
        LumiLLMProviderStatus(message: "custom status", level: .warning)
    }
}
