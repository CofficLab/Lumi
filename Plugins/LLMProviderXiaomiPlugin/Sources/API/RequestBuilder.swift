import Foundation
import LumiKernel

enum XiaomiRequestBuilder {
    static func body(for request: LumiLLMRequest) -> [String: Any] {
        var body: [String: Any] = [
            "model": request.model,
            "messages": request.messages.compactMap(message),
            "stream": true,
        ]
        if !request.tools.isEmpty {
            body["tools"] = request.tools.map { tool in
                ["type": "function", "function": [
                    "name": tool.name,
                    "description": tool.toolDescription,
                    "parameters": tool.inputSchema.anyValue,
                ]]
            }
        }
        return body
    }

    private static func message(_ message: LumiChatMessage) -> [String: Any]? {
        switch message.role {
        case .system, .user:
            return ["role": message.role.rawValue, "content": message.content]
        case .assistant:
            var value: [String: Any] = ["role": "assistant", "content": message.content]
            if let calls = message.toolCalls, !calls.isEmpty {
                value["tool_calls"] = calls.map { [
                    "id": $0.id,
                    "type": "function",
                    "function": ["name": $0.name, "arguments": $0.arguments],
                ] }
            }
            return value
        case .tool:
            guard let id = message.toolCallID else { return nil }
            return ["role": "tool", "tool_call_id": id, "content": message.content]
        case .error, .status:
            return nil
        }
    }
}
