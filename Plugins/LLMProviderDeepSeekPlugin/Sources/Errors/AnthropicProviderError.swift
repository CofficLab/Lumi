import Foundation
import KernelLumi

/// DeepSeek Anthropic 协议的 provider 错误。
///
/// 与 `DeepSeekOpenAIProviderError`（OpenAI 协议）平行存在，独立命名以便重试策略按 flavor 区分。
enum AnthropicProviderError: LocalizedError, LumiLLMErrorDispositionProviding {
    case invalidRequest(String)
    case invalidResponse(String)
    case api(String)
    /// 模型输出撞上 `max_tokens` 上限被截断，且没有任何可见回复
    /// （典型：thinking 吃掉全部输出预算后 `stop_reason = max_tokens`）。
    /// 关联值为输出 token 数（usage.output_tokens），便于 UI 提示用户。
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
            return "DeepSeek Anthropic hit the max_tokens limit \(detail) before producing any visible reply — the entire output budget was consumed by thinking. Increase max_tokens or disable thinking and retry."
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
