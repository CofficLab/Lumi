import Foundation
import LLMKit
import LLMProviderKit

extension SuperLLMProvider {
    /// 发送前消息整理（默认保留 system + 可发送角色）。
    public func prepareMessagesForProvider(_ messages: [ChatMessage]) -> [ChatMessage] {
        messages.filter { $0.role == .system || $0.shouldSendToLLM }
    }

    /// 生成参数写入请求体（默认 OpenAI 风格；供应商可覆盖）。
    public func applyGenerationOptions(config: LLMConfig, model: String, to body: inout [String: Any]) {
        OpenAICompatibleGenerationOptionsApplier.apply(config: config, model: model, to: &body)
    }

    /// 解析 HTTP 错误响应体。
    public func parseProviderHTTPError(data: Data?, statusCode: Int?) -> ProviderHTTPError? {
        ProviderHTTPErrorParser.parseGenericJSON(data: data, statusCode: statusCode)
    }

    /// 重试决策（供应商实例可覆盖）。
    public func retryDecision(
        for error: Error,
        statusCode: Int?,
        attempt: Int,
        maxAttempts: Int,
        retryAfter: TimeInterval? = nil
    ) -> ProviderRetryDecision {
        OpenAICompatibleProviderAdapter.retryDecision(
            for: error,
            statusCode: statusCode,
            attempt: attempt,
            maxAttempts: maxAttempts,
            retryAfter: retryAfter
        )
    }
}
