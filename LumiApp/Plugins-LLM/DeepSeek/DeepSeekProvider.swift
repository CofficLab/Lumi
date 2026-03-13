import Foundation
import OSLog
import MagicKit

// MARK: - DeepSeek 供应商

/// DeepSeek API 供应商实现
///
/// DeepSeek 兼容 OpenAI API 格式，因此继承 OpenAI 的实现逻辑。
final class DeepSeekProvider: NSObject, SuperLLMProvider, @unchecked Sendable {

    nonisolated static let emoji = "🔵"
    nonisolated static let verbose = false

    // MARK: - 基础信息

    static let id = "deepseek"
    static let displayName = "DeepSeek"
    static let iconName = "waveform.path"
    static let description = "DeepSeek AI"

    // MARK: - 配置相关

    static let apiKeyStorageKey = "DevAssistant_ApiKey_DeepSeek"
    static let modelStorageKey = "DevAssistant_Model_DeepSeek"

    static let defaultModel = "deepseek-chat"

    static let availableModels = [
        "deepseek-chat",       // DeepSeek Chat
        "deepseek-coder",      // DeepSeek Coder
        "deepseek-reasoner"
    ]

    // MARK: - SuperLLMProvider

    override init() {
        super.init()
    }

    var baseURL: String {
        "https://api.deepseek.com/chat/completions"
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
        // DeepSeek 兼容 OpenAI 格式
        let finalMessages = messages.map { transformMessage($0) }

        var body: [String: Any] = [
            "model": model,
            "messages": finalMessages,
            "stream": false,
        ]

        if let tools = tools, !tools.isEmpty {
            body["tools"] = tools.map { formatTool($0) }
        }

        return body
    }

    func parseResponse(data: Data) throws -> (content: String, toolCalls: [ToolCall]?) {
        // DeepSeek 响应格式与 OpenAI 兼容
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

    /// 构建流式请求体
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
    /// DeepSeek 兼容 OpenAI 流式格式
    func parseStreamChunk(data: Data) throws -> StreamChunk? {
        // 复用 OpenAI 的解析逻辑
        let openAIProvider = OpenAIProvider()
        return try openAIProvider.parseStreamChunk(data: data)
    }

    static var logEmoji: String { "🔵" }
}

// MARK: - 消息转换

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
