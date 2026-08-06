import Foundation
import LumiKernel

/// DeepSeek Anthropic 协议的 provider 错误。
///
/// 与 `DeepSeekOpenAIProviderError`（OpenAI 协议）平行存在，独立命名以便重试策略按 flavor 区分。
enum AnthropicProviderError: LocalizedError, LumiLLMErrorDispositionProviding {
    case invalidRequest(String)
    case invalidResponse(String)
    case api(String)

    var errorDescription: String? {
        switch self {
        case let .invalidRequest(value), let .invalidResponse(value), let .api(value): value
        }
    }

    var statusCode: Int? { nil }

    var llmErrorDisposition: LumiLLMErrorDisposition {
        switch self {
        case .api: .retryable()
        case .invalidRequest, .invalidResponse: .nonRetryable
        }
    }
}
