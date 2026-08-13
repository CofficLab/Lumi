import Foundation
import LLMKit
import KernelLumi

enum KimiCodeRequestBuilder {
    static func body(for request: LumiLLMRequest) -> [String: Any] {
        var body: [String: Any] = [
            "model": request.model,
            "messages": request.messages.compactMap(message),
            "stream": true,
        ]
        if !request.tools.isEmpty {
            body["tools"] = request.tools.map { tool in
                ["type": "function", "function": [
                    // Kimi Coding 端点校验函数名「以字母开头 + 仅字母/数字/_/-」，
                    // 带点号等非法字符的 MCP 工具名须转义，否则整包请求 400。
                    "name": LLMToolNameSanitizer.sanitize(tool.name),
                    "description": tool.toolDescription,
                    "parameters": tool.inputSchema.anyValue,
                ]]
            }
        }
        if let effort = request.reasoningEffort {
            body["reasoning_effort"] = effort.rawValue
        }
        return body
    }

    /// 建立「sanitize 后名字 → 原始注册名」的反查映射，供流式响应解析时还原。
    static func toolNameMap(for request: LumiLLMRequest) -> [String: String] {
        var map: [String: String] = [:]
        for tool in request.tools {
            let sanitized = LLMToolNameSanitizer.sanitize(tool.name)
            if map[sanitized] == nil { map[sanitized] = tool.name }
        }
        return map
    }

    private static func message(_ message: LumiChatMessage) -> [String: Any]? {
        switch message.role {
        case .system, .user:
            return ["role": message.role.rawValue, "content": message.content]
        case .assistant:
            var value: [String: Any] = ["role": "assistant", "content": message.content]
            if let calls = message.toolCalls, !calls.isEmpty {
                // 历史消息回传同样要转义，否则下一轮请求仍会被供应商 400 拒绝。
                value["tool_calls"] = calls.map { [
                    "id": $0.id,
                    "type": "function",
                    "function": ["name": LLMToolNameSanitizer.sanitize($0.name), "arguments": $0.arguments],
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