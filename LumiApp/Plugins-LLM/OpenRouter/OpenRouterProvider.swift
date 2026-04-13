import Foundation
import MagicKit
import os

// MARK: - OpenRouter Provider

/// OpenRouter 供应商实现
///
/// OpenRouter 是一个聚合多个 LLM 供应商的平台，API 兼容 OpenAI 格式。
/// 支持 Tool Calls 和流式响应。
final class OpenRouterProvider: NSObject, SuperLLMProvider, SuperLog, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "llm.openrouter")
    nonisolated static let emoji = "🔵"
    nonisolated static let verbose: Bool = true
    // MARK: - Basic Info

    static let id = "openrouter"
    static let displayName = String(localized: "OpenRouter", table: "OpenRouter")
    static let description = String(localized: "Multi-Provider LLM Router", table: "OpenRouter")

    // MARK: - Configuration

    static let apiKeyStorageKey = "DevAssistant_ApiKey_OpenRouter"
    static let defaultModel = "alibaba/qwen3.5-397b"

    static let availableModels = [
        "alibaba/qwen3.5-397b",
        "anthropic/claude-haiku-4-5-20251001",
        "anthropic/claude-opus-4-5-20251101",
        "anthropic/claude-sonnet-4-5-20250929",
        "bytedance-seed/seedream-4.5",
        "deepseek/deepseek-v3.1",
        "google/gemma-3-27b-it:free",
        "google/gemini-pro-2.5",
        "meta-llama/llama-3.3-70b-instruct",
        "minimax/minimax-m2.1",
        "minimax/minimax-m2.5:free",
        "nvidia/nemotron-3-super-120b-a12b:free",
        "openai/gpt-4o",
        "openai/gpt-5",
        "openai/gpt-5-mini",
        "openai/gpt-oss-20b:free",
        "qwen/qwen3.6-plus",
        "stepfun/step-3.5-flash:free",
        "z-ai/glm-4.5-air:free",
    ]

    static let contextWindowSizes: [String: Int] = [
        "alibaba/qwen3.5-397b": 131_072,
        "anthropic/claude-haiku-4-5-20251001": 200_000,
        "anthropic/claude-opus-4-5-20251101": 200_000,
        "anthropic/claude-sonnet-4-5-20250929": 200_000,
        "bytedance-seed/seedream-4.5": 128_000,
        "deepseek/deepseek-v3.1": 128_000,
        "google/gemma-3-27b-it:free": 131_072,
        "google/gemini-pro-2.5": 1_000_000,
        "meta-llama/llama-3.3-70b-instruct": 128_000,
        "minimax/minimax-m2.1": 1_000_000,
        "minimax/minimax-m2.5:free": 1_000_000,
        "nvidia/nemotron-3-super-120b-a12b:free": 128_000,
        "openai/gpt-4o": 128_000,
        "openai/gpt-5": 128_000,
        "openai/gpt-5-mini": 128_000,
        "openai/gpt-oss-20b:free": 128_000,
        "qwen/qwen3.6-plus": 131_072,
        "stepfun/step-3.5-flash:free": 128_000,
        "z-ai/glm-4.5-air:free": 128_000,
    ]

    // MARK: - SuperLLMProvider

    override init() {
        super.init()
    }

    var baseURL: String {
        "https://openrouter.ai/api/v1/chat/completions"
    }

    func buildRequest(url: URL, apiKey: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        // OpenRouter 要求的额外 header
        request.addValue("Lumi", forHTTPHeaderField: "HTTP-Referer")
        request.addValue("Lumi", forHTTPHeaderField: "X-Title")
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
        let result = try JSONDecoder().decode(OpenRouterResponse.self, from: data)

        guard let choiceMessage = result.choices.first?.message else {
            throw NSError(domain: "OpenRouterProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "No choices in response"])
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
    /// OpenRouter SSE 格式（兼容 OpenAI）：
    /// data: {"choices":[{"delta":{"content":"Hello"}}]}
    /// data: [DONE]
    func parseStreamChunk(data: Data) throws -> StreamChunk? {
        guard let text = String(data: data, encoding: .utf8) else {
            return nil
        }

        var eventData: String?

        let lines = text.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("data: ") {
                eventData = String(trimmed.dropFirst(6))
            }
        }

        guard let dataStr = eventData else {
            return nil
        }

        // 处理结束标记
        if dataStr == "[DONE]" {
            return StreamChunk(isDone: true)
        }

        guard let jsonData = dataStr.data(using: .utf8) else {
            return nil
        }

        do {
            let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

            // 处理错误
            if let error = json?["error"] as? [String: Any],
               let errorMessage = error["message"] as? String {
                return StreamChunk(error: errorMessage)
            }

            // 提取 usage 信息
            if let usage = json?["usage"] as? [String: Any] {
                let inputTokens = usage["prompt_tokens"] as? Int
                let outputTokens = usage["completion_tokens"] as? Int
                return StreamChunk(isDone: false, inputTokens: inputTokens, outputTokens: outputTokens)
            }

            // 提取内容增量
            if let choices = json?["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let delta = firstChoice["delta"] as? [String: Any] {
                if let content = delta["content"] as? String {
                    return StreamChunk(content: content, eventType: .textDelta)
                }

                if let toolCalls = delta["tool_calls"] as? [[String: Any]], !toolCalls.isEmpty {
                    var resultToolCalls: [ToolCall] = []
                    var partialJson: String?

                    for tc in toolCalls {
                        guard let function = tc["function"] as? [String: Any] else {
                            continue
                        }

                        if let toolId = function["id"] as? String ?? tc["id"] as? String,
                           let toolName = function["name"] as? String,
                           let arguments = function["arguments"] as? String {
                            let toolCall = ToolCall(id: toolId, name: toolName, arguments: arguments)
                            resultToolCalls.append(toolCall)
                        }

                        if let args = function["arguments"] as? String {
                            partialJson = args
                        }
                    }

                    if !resultToolCalls.isEmpty {
                        return StreamChunk(toolCalls: resultToolCalls, partialJson: partialJson, eventType: .contentBlockStart)
                    }

                    if let partial = partialJson {
                        return StreamChunk(partialJson: partial, eventType: .inputJsonDelta)
                    }
                }
            }

            // 如果没有解析出任何内容，返回空 chunk 避免卡住
            return StreamChunk(content: "", eventType: .textDelta)
        } catch {
            if Self.verbose {
                Self.logger.error("解析流式数据块失败：\(error.localizedDescription)")
            }
            return nil
        }
    }
}

// MARK: - 消息转换

extension OpenRouterProvider {
    func transformMessage(_ message: ChatMessage) -> [String: Any] {
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
                    "function": ["name": tc.name, "arguments": tc.arguments],
                ]
            }
        }

        return dict
    }
}

// MARK: - 工具格式

extension OpenRouterProvider {
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
