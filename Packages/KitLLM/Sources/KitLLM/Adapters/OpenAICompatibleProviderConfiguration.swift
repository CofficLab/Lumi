import Foundation

public struct OpenAICompatibleProviderConfiguration: Sendable, Equatable {
    public let baseURL: String
    public let fallbackBaseURLs: [String]
    public let additionalHeaders: [String: String]
    public let includeUsageInStreamOptions: Bool
    public let returnsEmptyChunkWhenNoDelta: Bool
    public let acceptsFunctionScopedToolCallID: Bool
    public let includesReasoningContentInMessages: Bool
    /// 该供应商额外接受的 `reasoning_effort` 档位。
    ///
    /// `reasoning_effort` 的合法取值**因供应商而异**：OpenAI 官方文档说明
    /// 档位「model-dependent」，而 MiniMax 明确支持 `xhigh` / `max`。
    /// 未知档位会让上游直接返回 400（不可重试），因此不能全局放宽——
    /// 供应商必须在这里显式声明自己接受的额外档位。
    ///
    /// 见 `OpenAICompatibleGenerationOptionsApplier.normalizedReasoningEffort`。
    public let additionalReasoningEfforts: [String]

    public init(
        baseURL: String,
        fallbackBaseURLs: [String] = [],
        additionalHeaders: [String: String] = [:],
        // OpenAI-compatible gateways generally expose final usage in a
        // usage-only SSE event. Request it by default so every provider that
        // uses the shared VendorLLMProvider can report output speed.
        includeUsageInStreamOptions: Bool = true,
        returnsEmptyChunkWhenNoDelta: Bool = false,
        acceptsFunctionScopedToolCallID: Bool = false,
        includesReasoningContentInMessages: Bool = false,
        additionalReasoningEfforts: [String] = []
    ) {
        self.baseURL = baseURL
        self.fallbackBaseURLs = fallbackBaseURLs
        self.additionalHeaders = additionalHeaders
        self.includeUsageInStreamOptions = includeUsageInStreamOptions
        self.returnsEmptyChunkWhenNoDelta = returnsEmptyChunkWhenNoDelta
        self.acceptsFunctionScopedToolCallID = acceptsFunctionScopedToolCallID
        self.includesReasoningContentInMessages = includesReasoningContentInMessages
        // 归一化为小写去空白，与归一化请求值的比较口径保持一致。
        self.additionalReasoningEfforts = additionalReasoningEfforts
            .map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
