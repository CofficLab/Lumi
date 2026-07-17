import Foundation
import HttpKit
import LLMKit
import LumiCoreKit

public typealias LumiOpenAICompatibleProviderConfiguration = OpenAICompatibleProviderConfiguration
public typealias LumiAnthropicCompatibleProviderConfiguration = AnthropicCompatibleProviderConfiguration

enum LumiLLMRequestMessages {
    static func preparedForProvider(_ request: LumiLLMRequest) -> [LLMKit.ChatMessage] {
        LumiVisionMessageSupport.preparedMessages(for: request)
    }
}

struct LumiToolSchema: LLMToolSchemaProviding {
    let name: String
    let toolDescription: String
    let inputSchema: [String: Any]

    init(_ tool: any LumiAgentTool) {
        self.name = tool.name
        self.toolDescription = tool.toolDescription
        self.inputSchema = tool.inputSchema.anyValue as? [String: Any] ?? [:]
    }
}
