import Foundation

/// 供应商对单次 LLM 失败给出的重试决策。
public struct LumiLLMErrorDisposition: Sendable, Equatable {
    public let isRetryable: Bool
    public let retryDelaySeconds: TimeInterval?

    public init(isRetryable: Bool, retryDelaySeconds: TimeInterval? = nil) {
        self.isRetryable = isRetryable
        self.retryDelaySeconds = retryDelaySeconds
    }

    public static let nonRetryable = LumiLLMErrorDisposition(isRetryable: false)

    public static func retryable(delay: TimeInterval? = nil) -> LumiLLMErrorDisposition {
        LumiLLMErrorDisposition(isRetryable: true, retryDelaySeconds: delay)
    }

    public var metadataEntries: [String: String] {
        var metadata = [LumiLLMErrorMetadata.retryable: isRetryable ? "true" : "false"]
        if let retryDelaySeconds {
            metadata[LumiLLMErrorMetadata.retryDelaySeconds] = String(retryDelaySeconds)
        }
        return metadata
    }

    public static func from(message: LumiChatMessage) -> LumiLLMErrorDisposition? {
        guard message.isError,
              let raw = message.metadata[LumiLLMErrorMetadata.retryable]
        else { return nil }

        let delay = message.metadata[LumiLLMErrorMetadata.retryDelaySeconds].flatMap(TimeInterval.init)
        return LumiLLMErrorDisposition(isRetryable: raw == "true", retryDelaySeconds: delay)
    }
}

public enum LumiLLMErrorMetadata {
    public static let retryable = "llm.error.retryable"
    public static let retryDelaySeconds = "llm.error.retryDelaySeconds"
}

/// 错误类型可声明自身的默认重试决策；供应商可在 `retryDisposition` 中覆盖。
public protocol LumiLLMErrorDispositionProviding: Error {
    var llmErrorDisposition: LumiLLMErrorDisposition { get }
}

/// 单次 LLM 调用的重试上下文（`attempt` 为 1-based）。
public struct LumiLLMRetryContext: Sendable, Equatable {
    public let attempt: Int
    public let maxAttempts: Int

    public init(attempt: Int, maxAttempts: Int) {
        self.attempt = attempt
        self.maxAttempts = maxAttempts
    }
}
