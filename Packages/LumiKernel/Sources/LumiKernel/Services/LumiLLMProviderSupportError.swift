import Foundation

public enum LumiLLMProviderSupportError: LocalizedError, LumiLLMErrorDispositionProviding {
    case emptyConversation
    case invalidBaseURL(String)
    case missingAPIKey(String)
    case allEndpointsFailed
    case streamingFailed(String)
    case emptyResponse

    public var llmErrorDisposition: LumiLLMErrorDisposition {
        switch self {
        case .emptyConversation, .invalidBaseURL, .missingAPIKey:
            return .nonRetryable
        case .allEndpointsFailed, .streamingFailed, .emptyResponse:
            return .retryable(delay: 2.0)
        }
    }

    public var errorDescription: String? {
        switch self {
        case .emptyConversation: return "Conversation is empty"
        case .invalidBaseURL(let url): return "Invalid base URL: \(url)"
        case .missingAPIKey(let provider): return "Missing API key for: \(provider)"
        case .allEndpointsFailed: return "All endpoints failed"
        case .streamingFailed(let reason): return "Streaming failed: \(reason)"
        case .emptyResponse: return "Empty response from provider"
        }
    }
}
