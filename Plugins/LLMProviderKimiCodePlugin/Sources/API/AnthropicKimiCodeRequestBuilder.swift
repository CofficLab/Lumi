import Foundation
import LLMKit
import LumiKernel

enum AnthropicKimiCodeRequestBuilder {
    static let defaultMaxTokens = 8192
    static let defaultThinkingBudget = 1024
    static let maxThinkingBudget = defaultMaxTokens - 1024

    static func body(for request: LumiLLMRequest) -> [String: Any] {
        var body: [String: Any] = [
            "model": request.model,
            "max_tokens": defaultMaxTokens,
            "stream": true,
        ]

        let (systemMessages, conversation) = partition(request.messages)
        if !systemMessages.isEmpty {
            body["system"] = mergeSystem(systemMessages)
        }

        body["messages"] = buildConversation(conversation)

        if !request.tools.isEmpty {
            body["tools"] = request.tools.map(tool)
        }

        let requested = thinkingBudget(for: request.reasoningEffort)
            ?? defaultThinkingBudget
        body["thinking"] = [
            "type": "enabled",
            "budget_tokens": min(requested, maxThinkingBudget),
        ]

        return body
    }

    private static func partition(_ messages: [LumiChatMessage]) -> (system: [LumiChatMessage], rest: [LumiChatMessage]) {
        var system: [LumiChatMessage] = []
        var rest: [LumiChatMessage] = []
        for message in messages {
            if message.role == .system { system.append(message) }
            else if message.role == .error || message.role == .status { continue }
            else { rest.append(message) }
        }
        return (system, rest)
    }

    private static func mergeSystem(_ messages: [LumiChatMessage]) -> Any {
        let texts = messages.map(\.content).filter { !$0.isEmpty }
        if texts.count <= 1, let only = texts.first { return only }
        return texts.map { ["type": "text", "text": $0] }
    }

    private static func buildConversation(_ messages: [LumiChatMessage]) -> [[String: Any]] {
        var result: [[String: Any]] = []
        var pendingToolResults: [[String: Any]] = []

        for message in messages {
            if message.role == .tool {
                if let toolCallID = message.toolCallID {
                    pendingToolResults.append([
                        "type": "tool_result",
                        "tool_use_id": toolCallID,
                        "content": toolResultContent(for: message),
                    ])
                }
                continue
            }
            if !pendingToolResults.isEmpty {
                result.append(["role": "user", "content": pendingToolResults])
                pendingToolResults = []
            }
            if let mapped = Self.message(message) {
                result.append(mapped)
            }
        }
        if !pendingToolResults.isEmpty {
            result.append(["role": "user", "content": pendingToolResults])
        }
        return result
    }

    private static func message(_ message: LumiChatMessage) -> [String: Any]? {
        switch message.role {
        case .system, .error, .status:
            return nil
        case .user:
            return [
                "role": "user",
                "content": anthropicContentBlocks(for: message),
            ]
        case .assistant:
            var blocks: [[String: Any]] = []
            if let reasoning = message.reasoningContent, !reasoning.isEmpty {
                blocks.append([
                    "type": "thinking",
                    "thinking": reasoning,
                    "signature": message.metadata["thinkingSignature"] ?? "",
                ])
            }
            if !message.content.isEmpty {
                blocks.append(contentsOf: textContentBlocks(for: message.content))
            }
            if let calls = message.toolCalls {
                for call in calls {
                    blocks.append([
                        "type": "tool_use",
                        "id": call.id,
                        "name": sanitizeToolName(call.name),
                        "input": parseJSONObject(call.arguments),
                    ])
                }
            }
            if blocks.isEmpty { return nil }
            return ["role": "assistant", "content": blocks]
        case .tool:
            return nil
        }
    }

    private static func textContentBlocks(for text: String) -> [[String: Any]] {
        guard !text.isEmpty else { return [] }
        return [["type": "text", "text": text]]
    }

    private static func anthropicContentBlocks(for message: LumiChatMessage) -> [[String: Any]] {
        VisionMessageContentBuilder.anthropicBlocks(
            text: message.content,
            images: LumiVisionMessageSupport.messageImages(from: message.metadata)
        )
    }

    private static func toolResultContent(for message: LumiChatMessage) -> Any {
        let images = LumiVisionMessageSupport.messageImages(from: message.metadata)
        guard !images.isEmpty else { return message.content }
        return VisionMessageContentBuilder.anthropicBlocks(text: message.content, images: images)
    }

    private static func tool(_ tool: any LumiAgentTool) -> [String: Any] {
        var value: [String: Any] = [
            "name": sanitizeToolName(tool.name),
            "input_schema": tool.inputSchema.anyValue,
        ]
        if !tool.toolDescription.isEmpty {
            value["description"] = tool.toolDescription
        }
        return value
    }

    static func toolNameMap(for request: LumiLLMRequest) -> [String: String] {
        var map: [String: String] = [:]
        for tool in request.tools {
            let sanitized = sanitizeToolName(tool.name)
            if map[sanitized] == nil { map[sanitized] = tool.name }
        }
        return map
    }

    static func sanitizeToolName(_ raw: String) -> String {
        var result = ""
        result.reserveCapacity(raw.utf8.count)
        for byte in raw.utf8 {
            let isLegal =
                (byte >= 0x61 && byte <= 0x7A) ||
                (byte >= 0x41 && byte <= 0x5A) ||
                (byte >= 0x30 && byte <= 0x39) ||
                byte == 0x5F || byte == 0x2D
            result.append(Character(UnicodeScalar(isLegal ? byte : 0x5F)))
        }
        return result.isEmpty ? "tool" : result
    }

    private static func thinkingBudget(for effort: LumiReasoningEffort?) -> Int? {
        switch effort {
        case nil: nil
        case .low: 2048
        case .medium: 3072
        case .high: 4096
        case .xhigh: 8192
        case .max: 16384
        }
    }

    private static func parseJSONObject(_ jsonString: String) -> [String: Any]? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
