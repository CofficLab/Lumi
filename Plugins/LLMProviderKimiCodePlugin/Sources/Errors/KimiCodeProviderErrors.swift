import Foundation
import KernelLumi

enum KimiCodeOpenAIProviderError: LocalizedError, LumiLLMErrorDispositionProviding {
    case invalidRequest(String)
    case invalidResponse(String)
    case api(String)
    case maxTokensExceeded(Int?)

    var errorDescription: String? {
        switch self {
        case let .invalidRequest(msg): return "Kimi Code request error: \(msg)"
        case let .invalidResponse(msg): return "Kimi Code response error: \(msg)"
        case let .api(msg): return "Kimi Code API error: \(msg)"
        case let .maxTokensExceeded(tokens):
            if let t = tokens {
                return "Kimi Code output exceeded max_tokens (\(t) tokens), no visible content generated"
            }
            return "Kimi Code output exceeded max_tokens, no visible content generated"
        }
    }

    var llmErrorDisposition: LumiLLMErrorDisposition {
        switch self {
        case .invalidRequest: return .nonRetryable
        case .invalidResponse, .api, .maxTokensExceeded: return .retryable()
        }
    }
}

enum KimiCodeAnthropicProviderError: LocalizedError, LumiLLMErrorDispositionProviding {
    case invalidRequest(String)
    case invalidResponse(String)
    case api(String)
    case maxTokensExceeded(Int?)

    var errorDescription: String? {
        switch self {
        case let .invalidRequest(msg): return "Kimi Code Anthropic request error: \(msg)"
        case let .invalidResponse(msg): return "Kimi Code Anthropic response error: \(msg)"
        case let .api(msg): return "Kimi Code Anthropic API error: \(msg)"
        case let .maxTokensExceeded(tokens):
            if let t = tokens {
                return "Kimi Code Anthropic output exceeded max_tokens (\(t) tokens), no visible content generated"
            }
            return "Kimi Code Anthropic output exceeded max_tokens, no visible content generated"
        }
    }

    var llmErrorDisposition: LumiLLMErrorDisposition {
        switch self {
        case .invalidRequest: return .nonRetryable
        case .invalidResponse, .api, .maxTokensExceeded: return .retryable()
        }
    }
}