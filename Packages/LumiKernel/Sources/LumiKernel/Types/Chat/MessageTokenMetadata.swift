import Foundation

public enum MessageTokenMetadata {
    public static let inputKey = "inputTokens"
    public static let outputKey = "outputTokens"
    public static let cachedInputKey = "cachedInputTokens"
    public static let cacheWriteInputKey = "cacheWriteInputTokens"
    public static let cacheTotalInputKey = "cacheTotalInputTokens"

    public static func metadata(
        inputTokens: Int?,
        outputTokens: Int?,
        cachedInputTokens: Int? = nil,
        cacheWriteInputTokens: Int? = nil,
        cacheTotalInputTokens: Int? = nil
    ) -> [String: String] {
        var metadata: [String: String] = [:]
        if let inputTokens {
            metadata[inputKey] = String(inputTokens)
        }
        if let outputTokens {
            metadata[outputKey] = String(outputTokens)
        }
        if let cachedInputTokens {
            metadata[cachedInputKey] = String(cachedInputTokens)
        }
        if let cacheWriteInputTokens {
            metadata[cacheWriteInputKey] = String(cacheWriteInputTokens)
        }
        if let cacheTotalInputTokens {
            metadata[cacheTotalInputKey] = String(cacheTotalInputTokens)
        }
        return metadata
    }
}
