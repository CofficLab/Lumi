import Foundation
import OSLog
import MagicKit

// MARK: - OpenAI 供应商

/// OpenAI API 供应商实现
///
/// 此实现也适用于兼容 OpenAI API 格式的其他服务（如 DeepSeek）。
struct OpenAIProvider: LLMProviderProtocol {

    nonisolated static let emoji = "🟢"
    nonisolated static let verbose = false

    // MARK: - 基础信息

    static let id = "openai"
    static let displayName = "OpenAI"
    static let iconName = "sparkle"
    static let description = "GPT by OpenAI"

    // MARK: - 配置相关

    static let apiKeyStorageKey = "DevAssistant_ApiKey_OpenAI"
    static let modelStorageKey = "DevAssistant_Model_OpenAI"

    static let defaultModel = "gpt-4o"

    static let availableModels = [
        "gpt-4o",              // GPT-4 Omni（最新）
        "gpt-4o-mini",         // GPT-4 Omni Mini
        "gpt-4-turbo",         // GPT-4 Turbo
        "gpt-4",               // GPT-4
        "gpt-3.5-turbo",       // GPT-3.5 Turbo
    ]

    // MARK: - LLMProviderProtocol

    var baseURL: String {
        "https://api.openai.com/v1/chat/completions"
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
        // 转换消息格式
        let finalMessages = messages.map { transformMessage($0) }

        var body: [String: Any] = [
            "model": model,
            "messages": finalMessages,
            "stream": false,
        ]

        // 添加工具定义（如果存在）
        if let tools = tools, !tools.isEmpty {
            body["tools"] = tools.map { formatTool($0) }
        }

        return body
    }

    func parseResponse(data: Data) throws -> (content: String, toolCalls: [ToolCall]?) {
        struct OpenAIResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String?
                    struct ToolCall: Decodable {
                        let id: String
                        let type: String
                        struct Function: Decodable {
                            let name: String
                            let arguments: String
                        }
                        let function: Function
                    }
                    let tool_calls: [ToolCall]?
                }
                let message: Message
            }
            let choices: [Choice]
        }

        let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let choiceMessage = result.choices.first?.message else {
            throw NSError(domain: "OpenAIProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "No choices in response"])
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

    static var logEmoji: String { "🟢" }
}

// MARK: - 消息转换

extension OpenAIProvider {

    /// 将 ChatMessage 转换为 OpenAI 格式
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

// MARK: - 工具格式

extension OpenAIProvider {

    /// 将 AgentTool 转换为 OpenAI 格式
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
