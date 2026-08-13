import Foundation
import KernelLumi

/// StepFun Provider 在请求/响应/远端 API 失败时抛出的领域错误。
enum StepFunProviderError: LocalizedError, LumiLLMErrorDispositionProviding {
    case invalidRequest(String)
    case invalidResponse(String)
    case api(String)
    /// 模型输出撞上 `max_tokens` 上限被截断，且没有任何可见回复。
    case maxTokensExceeded(Int?)

    var errorDescription: String? {
        switch self {
        case let .invalidRequest(value):
            return value
        case let .invalidResponse(value):
            return value
        case let .api(value):
            return value
        case let .maxTokensExceeded(outputTokens):
            let detail = outputTokens.map { "(\($0) tokens)" } ?? ""
            return "StepFun hit the max_tokens limit \(detail) before producing any visible reply. Increase max_tokens and retry."
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