import Foundation

/// A deliberately inert default. The host or an LLM plugin replaces it with a
/// real provider before sending a turn; the kernel remains launchable offline.
public final class DefaultLLMProviding: LLMProviding, @unchecked Sendable {
    public let providerID: String

    public init(providerID: String = "default") {
        self.providerID = providerID
    }

    public func complete(_ request: LLMRequest) async throws -> LLMResponse {
        throw LLMProviderError.notConfigured
    }
}

