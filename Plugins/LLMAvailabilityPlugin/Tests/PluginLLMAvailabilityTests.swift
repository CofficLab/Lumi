import Testing
import Foundation
import AgentToolKit
import LLMKit
import LLMProviderKit
import LumiCoreKit
@testable import LLMAvailabilityPlugin

@Test func packageLoads() async throws {
    #expect(LLMAvailabilityPlugin.policy == .alwaysOn)
}

@Suite(.serialized)
@MainActor
struct LLMAvailabilityCheckerTests {
    @Test func availabilityCheckerUsesInjectedService() async throws {
        let providerInfo = LLMProviderInfo(
            id: "availability-mock",
            displayName: "Availability Mock",
            shortName: "Mock",
            description: "Mock provider for availability tests",
            websiteURL: nil,
            availableModels: ["mock-model"],
            defaultModel: "mock-model",
            isLocal: false,
            isEnabled: true,
            contextWindowSizes: [:]
        )

        let service = AvailabilityMockLLMService(providerInfo: providerInfo)
        LLMAvailabilityStore.shared.initialize(providers: [providerInfo])
        let result = await LLMAvailabilityChecker(llmService: service)
            .checkModel(providerId: providerInfo.id, modelId: providerInfo.defaultModel)

        #expect(result.isAvailable)
        #expect(result.reason == nil)
        #expect(
            LLMAvailabilityStore.shared.status(
                providerId: providerInfo.id,
                modelId: providerInfo.defaultModel
            ) == .available
        )
    }

    @Test func lumiAdapterDelegatesToProviderCheckAvailability() async throws {
        let provider = AvailabilityMockLumiProvider(
            checkResult: .unavailable(.message("endpoint unreachable"))
        )
        let adapter = LumiProviderAvailabilityAdapter(providers: [provider])
        let providerInfo = adapter.allProviders()[0]

        LLMAvailabilityStore.shared.initialize(providers: [providerInfo])
        let result = await LLMAvailabilityChecker(llmService: adapter)
            .checkModel(providerId: providerInfo.id, modelId: providerInfo.defaultModel)

        #expect(!result.isAvailable)
        #expect(result.reason == "endpoint unreachable")
        #expect(
            LLMAvailabilityStore.shared.status(
                providerId: providerInfo.id,
                modelId: providerInfo.defaultModel
            ) == .unavailable(.message("endpoint unreachable"))
        )
    }
}

private struct AvailabilityMockLLMService: LLMAvailabilityLLMServicing {
    let providerInfo: LLMProviderInfo

    func allProviders() -> [LLMProviderInfo] {
        [providerInfo]
    }

    func providerType(forId providerId: String) -> (any LLMAvailabilityProviderType)? {
        guard providerId == providerInfo.id else { return nil }
        return AvailabilityMockProviderType()
    }

    func createProvider(id providerId: String) -> (any LLMAvailabilityCheckingProvider)? {
        guard providerId == providerInfo.id else { return nil }
        return AvailabilityMockCheckingProvider()
    }

    func sendMessage(
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?
    ) async throws -> ChatMessage {
        ChatMessage(role: .assistant, content: "ok")
    }
}

private struct AvailabilityMockProviderType: LLMAvailabilityProviderType {
    var hasApiKey: Bool { true }
    func getApiKey() -> String { "test-key" }
}

private struct AvailabilityMockCheckingProvider: LLMAvailabilityCheckingProvider {
    func availabilityCheckStrategy(forModel modelId: String) -> AvailabilityCheckStrategy {
        .apiKeyOnly
    }
}

private struct AvailabilityMockLumiProvider: LumiLLMProvider {
    static let info = LumiLLMProviderInfo(
        id: "lumi-mock",
        displayName: "Lumi Mock",
        description: "Mock Lumi provider for availability tests",
        defaultModel: "mock-model",
        availableModels: ["mock-model"],
        isLocal: true,
        websiteURL: URL(string: "https://example.com")!
    )

    let checkResult: LumiModelAvailabilityResult

    func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        LumiChatMessage(
            conversationID: request.messages.first?.conversationID ?? UUID(),
            role: .assistant,
            content: "ok"
        )
    }

    func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        checkResult
    }

    func providerStatus() -> LumiLLMProviderStatus? {
        nil
    }
}
