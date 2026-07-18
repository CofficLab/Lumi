import Foundation
import LLMKit

public enum LLMRequestMessages {
    public static func preparedForProvider(_ request: LumiLLMRequest) -> [LLMKit.ChatMessage] {
        VisionMessageSupport.preparedMessages(for: request)
    }
}

public struct LLMToolSchema: LLMToolSchemaProviding {
    public let name: String
    public let toolDescription: String
    public let inputSchema: [String: Any]

    public init(_ tool: any LumiAgentTool) {
        self.name = tool.name
        self.toolDescription = tool.toolDescription
        self.inputSchema = tool.inputSchema.anyValue as? [String: Any] ?? [:]
    }
}
