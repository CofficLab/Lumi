import Foundation

public struct OpenAICompatibleProviderConfiguration: Sendable, Equatable {
    public let baseURL: String
    public let fallbackBaseURLs: [String]
    public let additionalHeaders: [String: String]
    public let includeUsageInStreamOptions: Bool
    public let returnsEmptyChunkWhenNoDelta: Bool
    public let acceptsFunctionScopedToolCallID: Bool
    public let includesReasoningContentInMessages: Bool

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
        includesReasoningContentInMessages: Bool = false
    ) {
        self.baseURL = baseURL
        self.fallbackBaseURLs = fallbackBaseURLs
        self.additionalHeaders = additionalHeaders
        self.includeUsageInStreamOptions = includeUsageInStreamOptions
        self.returnsEmptyChunkWhenNoDelta = returnsEmptyChunkWhenNoDelta
        self.acceptsFunctionScopedToolCallID = acceptsFunctionScopedToolCallID
        self.includesReasoningContentInMessages = includesReasoningContentInMessages
    }
}
