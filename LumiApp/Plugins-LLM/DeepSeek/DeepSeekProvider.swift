import Foundation
import MagicKit
import os

// MARK: - DeepSeek Provider

/// DeepSeek 供应商实现
///
/// DeepSeek API 兼容 OpenAI 格式，支持 Tool Calls 和流式响应。
/// API 地址：https://api.deepseek.com/v1/chat/completions
final class DeepSeekProvider: NSObject, SuperLLMProvider, SuperLog, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "llm.deepseek")
    nonisolated static let emoji = "🟠"
    nonisolated static let verbose = true

    // MARK: - Basic Info

    static let id = "deepseek"
    static let displayName = String(localized: "DeepSeek", table: "DeepSeek")
    static let iconName = "cpu"
    static let description = String(localized: "DeepSeek AI", table: "DeepSeek")

    // MARK: - Configuration

    static let apiKeyStorageKey = "DevAssistant_ApiKey_DeepSeek"
    static let modelStorageKey = "DevAssistant_Model_DeepSeek"
    static let defaultModel = "deepseek-chat"

    static let availableModels = [
        "deepseek-chat",      // DeepSeek Chat
        "deepseek-coder",     // DeepSeek Coder
    ]

    // MARK: - SuperLLMProvider

    override init() {
        super.init()
    }

    var baseURL: String {
        "https://api.deepseek.com/v1/chat/completions"
    }

    func buildRequest(url: URL, apiKey: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    func buildRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [AgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any] {
        let conversationMessages = messages.map { transformMessage($0) }

        var body: [String: Any] = [
            "model": model,
            "messages": conversationMessages,
            "stream": false,
        ]

        if let tools = tools, !tools.isEmpty {
            body["tools"] = tools.map { formatTool($0) }
        }

        return body
    }

    func parseResponse(data: Data) throws -> (content: String, toolCalls: [ToolCall]?) {
        let result = try JSONDecoder().decode(DeepSeekResponse.self, from: data)
        
        guard let choiceMessage = result.choices.first?.message else {
            throw NSError(domain: "DeepSeekProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "No choices in response"])
        }

        let content = choiceMessage.content ?? ""

        var toolCalls: [ToolCall]?
        if let apiToolCalls = choiceMessage.tool_calls {
            toolCalls = apiToolCalls.map { tc in
                ToolCall(id: tc.id, name: tc.function.name, arguments: tc.function.arguments)
            }
        }

        return (content, toolCalls)
    }

    func buildStreamingRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [AgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any] {
        var body = try buildRequestBody(
            messages: messages,
            model: model,
            tools: tools,
            systemPrompt: systemPrompt
        )
        body["stream"] = true
        return body
    }

    /// 解析流式响应数据块
    ///
    /// DeepSeek 的流式响应格式兼容 OpenAI：
    /// - 正常内容：使用 OpenAI 格式
    /// - 结束标记：`data: [DONE]`
    func parseStreamChunk(data: Data) throws -> StreamChunk? {
        // 复用 OpenAI 的解析逻辑
        let openAIProvider = OpenAIProvider()
        return try openAIProvider.parseStreamChunk(data: data)
    }

    static var logEmoji: String { "🟠" }
}

// MARK: - Message Transformation

extension DeepSeekProvider {
    func transformMessage(_ message: ChatMessage) -> [String: Any] {
        // 工具结果消息
        if let toolCallID = message.toolCallID {
            return [
                "role": "tool",
                "tool_call_id": toolCallID,
                "content": message.content,
            ]
        }

        // 带工具调用的助手消息
        var dict: [String: Any] = [
            "role": message.role.rawValue,
            "content": message.content,
        ]

        if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
            dict["tool_calls"] = toolCalls.map { tc in
                [
                    "id": tc.id,
                    "type": "function",
                    "function": [
                        "name": tc.name,
                        "arguments": tc.arguments,
                    ],
                ]
            }
        }

        return dict
    }
}

// MARK: - Tool Formatting

extension DeepSeekProvider {
    func formatTool(_ tool: AgentTool) -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": tool.name,
                "description": tool.description,
                "parameters": tool.inputSchema,
            ],
        ]
    }
}