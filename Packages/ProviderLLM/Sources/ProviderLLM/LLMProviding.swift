import Foundation
import ProviderMessage

/// Provider-facing request. Protocol details (OpenAI, Anthropic, local models)
/// stay outside KernelCore and are translated by each concrete provider.
public struct LLMRequest: Sendable {
    public let conversationID: UUID
    public let messages: [Message]
    public let model: String?

    public init(conversationID: UUID, messages: [Message], model: String? = nil) {
        self.conversationID = conversationID
        self.messages = messages
        self.model = model
    }
}

public struct LLMResponse: Sendable, Equatable {
    public let content: String
    public let model: String?

    public init(content: String, model: String? = nil) {
        self.content = content
        self.model = model
    }
}

public enum LLMProviderError: Error, LocalizedError, Sendable, Equatable {
    case notConfigured
    case emptyResponse
    case providerUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured: return "LLM provider is not configured"
        case .emptyResponse: return "LLM provider returned an empty response"
        case .providerUnavailable(let reason): return "LLM provider unavailable: \(reason)"
        }
    }
}

/// Minimal model boundary consumed by AgentLoop. Concrete network/auth/protocol
/// implementations belong in Provider packages or plugins.
public protocol LLMProviding: AnyObject, Sendable {
    var providerID: String { get }
    func complete(_ request: LLMRequest) async throws -> LLMResponse
}

