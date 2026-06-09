import AgentToolKit
import Foundation
import LLMKit
import LLMProviderKit

public protocol LLMAvailabilityProviderType: Sendable {
    var hasApiKey: Bool { get }
    func getApiKey() -> String
}

public protocol LLMAvailabilityCheckingProvider: Sendable {
    func availabilityCheckStrategy(forModel modelId: String) -> AvailabilityCheckStrategy
}

public protocol LLMAvailabilityLLMServicing: Sendable {
    func allProviders() -> [LLMProviderInfo]
    func providerType(forId providerId: String) -> (any LLMAvailabilityProviderType)?
    func createProvider(id providerId: String) -> (any LLMAvailabilityCheckingProvider)?
    func sendMessage(
        messages: [ChatMessage],
        config: LLMConfig,
        tools: [SuperAgentTool]?
    ) async throws -> ChatMessage
}

public enum LLMAvailabilityRuntime {
    nonisolated(unsafe) public static var llmService: (any LLMAvailabilityLLMServicing)?
}
