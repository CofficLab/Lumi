import Foundation

public struct OpenAICompatibleProviderConfiguration: Sendable, Equatable {
    public let baseURL: String
    public let additionalHeaders: [String: String]
    public let includeUsageInStreamOptions: Bool
    public let returnsEmptyChunkWhenNoDelta: Bool
    public let acceptsFunctionScopedToolCallID: Bool
    public let includesReasoningContentInMessages: Bool

    public init(
        baseURL: String,
        additionalHeaders: [String: String] = [:],
        includeUsageInStreamOptions: Bool = false,
        returnsEmptyChunkWhenNoDelta: Bool = false,
        acceptsFunctionScopedToolCallID: Bool = false,
        includesReasoningContentInMessages: Bool = false
    ) {
        self.baseURL = baseURL
        self.additionalHeaders = additionalHeaders
        self.includeUsageInStreamOptions = includeUsageInStreamOptions
        self.returnsEmptyChunkWhenNoDelta = returnsEmptyChunkWhenNoDelta
        self.acceptsFunctionScopedToolCallID = acceptsFunctionScopedToolCallID
        self.includesReasoningContentInMessages = includesReasoningContentInMessages
    }
}
