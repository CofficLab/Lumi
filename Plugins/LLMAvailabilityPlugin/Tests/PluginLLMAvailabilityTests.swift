import Testing
import Foundation
import AgentToolKit
import LLMKit
import LLMProviderKit
@testable import LLMAvailabilityPlugin

@Test func packageLoads() async throws {
    #expect(LLMAvailabilityPlugin.policy == .alwaysOn)
}

@MainActor
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
