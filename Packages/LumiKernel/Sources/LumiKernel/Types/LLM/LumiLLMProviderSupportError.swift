import Foundation

public enum LumiLLMProviderSupportError: LocalizedError, LumiLLMErrorDispositionProviding {
    case emptyConversation
    case invalidBaseURL(String)
    case missingAPIKey(String)
    case apiKeyAccessFailed(provider: String, details: String)
    case allEndpointsFailed
    case streamingFailed(String)
    case emptyResponse

    public var llmErrorDisposition: LumiLLMErrorDisposition {
        switch self {
        case .emptyConversation, .invalidBaseURL, .missingAPIKey:
            return .nonRetryable
        case .apiKeyAccessFailed, .allEndpointsFailed, .streamingFailed, .emptyResponse:
            return .retryable(delay: 2.0)
        }
    }

    public var errorDescription: String? {
        switch self {
        case .emptyConversation: return "Conversation is empty"
        case .invalidBaseURL(let url): return "Invalid base URL: \(url)"
        case .missingAPIKey(let provider): return "Missing API key for: \(provider)"
        case .apiKeyAccessFailed(let provider, let details):
            return "\(provider) API Key could not be read from macOS Keychain. \(details)"
        case .allEndpointsFailed: return "All endpoints failed"
        case .streamingFailed(let reason): return "Streaming failed: \(reason)"
        case .emptyResponse: return "Empty response from provider"
        }
    }
}
