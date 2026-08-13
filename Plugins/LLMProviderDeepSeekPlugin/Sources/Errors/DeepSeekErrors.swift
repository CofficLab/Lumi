import Foundation
import KernelLumi

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
    /// 模型输出撞上 `max_tokens` 上限被截断（OpenAI 端点 `finish_reason = "length"`），
    /// 且没有任何可见回复（thinking 吃掉全部输出预算的典型场景）。
    /// 关联值为输出 token 数，便于 UI 提示用户。
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
            return "DeepSeek hit the max_tokens limit \(detail) before producing any visible reply — the entire output budget was consumed by thinking. Increase max_tokens or disable thinking and retry."
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
