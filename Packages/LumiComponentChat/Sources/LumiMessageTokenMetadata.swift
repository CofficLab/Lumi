import Foundation
import LumiComponentMessage

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