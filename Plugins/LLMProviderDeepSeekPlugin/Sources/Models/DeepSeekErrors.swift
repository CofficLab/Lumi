import Foundation
import LumiKernel

/// DeepSeek (OpenAI-compatible flavor) provider 在请求/响应/远端 API 失败时抛出的领域错误。
///
/// 包含一个共享的 `llmErrorDisposition` 以便上层 LLM 重试层在调用 `retryDisposition`
/// 时能直接匹配。`statusCode` 默认 nil；provider 在 `makeErrorMessage` 中可补充 HTTP 状态。
///
/// 与 `DeepSeekAnthropicProviderError`（Anthropic-compatible flavor）平行存在，
/// 二者独立命名以便重试策略按协议 flavor 区分。
enum DeepSeekOpenAIProviderError: LocalizedError, LumiLLMErrorDispositionProviding {
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
