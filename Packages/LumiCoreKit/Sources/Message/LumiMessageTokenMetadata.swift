import Foundation

public enum LumiMessageTokenMetadata {
    public static let inputKey = "inputTokens"
    public static let outputKey = "outputTokens"

    public static func metadata(inputTokens: Int?, outputTokens: Int?) -> [String: String] {
        var metadata: [String: String] = [:]
        if let inputTokens {
            metadata[inputKey] = String(inputTokens)
        }
        if let outputTokens {
            metadata[outputKey] = String(outputTokens)
        }
        return metadata
    }
}

public extension LumiChatMessage {
    var inputTokenCount: Int? {
        metadata[LumiMessageTokenMetadata.inputKey].flatMap(Int.init)
    }

    var outputTokenCount: Int? {
        metadata[LumiMessageTokenMetadata.outputKey].flatMap(Int.init)
    }

    func withTokenMetadata(inputTokens: Int?, outputTokens: Int?) -> LumiChatMessage {
        var updated = self
        updated.metadata.merge(LumiMessageTokenMetadata.metadata(inputTokens: inputTokens, outputTokens: outputTokens)) { _, new in new }
        return updated
    }
}
