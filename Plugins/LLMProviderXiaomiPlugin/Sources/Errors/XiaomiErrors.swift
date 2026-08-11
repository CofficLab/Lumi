import Foundation
import LumiKernel

/// Xiaomi provider 在请求/响应/远端 API 失败时抛出的领域错误。
///
/// 包含一个共享的 `llmErrorDisposition` 以便上层 LLM 重试层在调用 `retryDisposition`
/// 时能直接匹配。`statusCode` 默认 nil；provider 在 `makeErrorMessage` 中可补充 HTTP 状态。
enum XiaomiOpenAIProviderError: LocalizedError, LumiLLMErrorDispositionProviding {
    case invalidRequest(String)
    case invalidResponse(String)
    case api(String)
    case maxTokensExceeded

    var errorDescription: String? {
        switch self {
        case let .invalidRequest(value):
            return value
        case let .invalidResponse(value):
            return value
        case let .api(value):
            return value
        case .maxTokensExceeded:
            return "Xiaomi hit the max_tokens limit before producing any visible reply. Increase max_tokens and retry."
        }
    }

    var statusCode: Int? { nil }

    var llmErrorDisposition: LumiLLMErrorDisposition {
        switch self {
        case .api: .retryable()
        case .invalidRequest, .invalidResponse, .maxTokensExceeded: .nonRetryable
        }
    }
}
