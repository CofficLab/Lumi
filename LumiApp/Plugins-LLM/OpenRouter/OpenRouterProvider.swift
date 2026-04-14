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

    static let modelCatalog: [LLMModelCatalogItem] = [
        .init(id: "alibaba/qwen3.5-397b", spec: .init(contextWindowSize: 131_072, supportsVision: false, supportsTools: true)),
        .init(id: "anthropic/claude-haiku-4-5-20251001", spec: .init(contextWindowSize: 200_000, supportsVision: true, supportsTools: true)),
        .init(id: "anthropic/claude-opus-4-5-20251101", spec: .init(contextWindowSize: 200_000, supportsVision: true, supportsTools: true)),
        .init(id: "anthropic/claude-sonnet-4-5-20250929", spec: .init(contextWindowSize: 200_000, supportsVision: true, supportsTools: true)),
        .init(id: "bytedance-seed/seedream-4.5", spec: .init(contextWindowSize: 128_000, supportsVision: true, supportsTools: true)),
        .init(id: "deepseek/deepseek-v3.1", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
        .init(id: "google/gemma-3-27b-it:free", spec: .init(contextWindowSize: 131_072, supportsVision: true, supportsTools: true)),
        .init(id: "google/gemini-pro-2.5", spec: .init(contextWindowSize: 1_000_000, supportsVision: true, supportsTools: true)),
        .init(id: "meta-llama/llama-3.3-70b-instruct", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
        .init(id: "minimax/minimax-m2.1", spec: .init(contextWindowSize: 1_000_000, supportsVision: false, supportsTools: true)),
        .init(id: "minimax/minimax-m2.5:free", spec: .init(contextWindowSize: 1_000_000, supportsVision: false, supportsTools: true)),
        .init(id: "nvidia/nemotron-3-super-120b-a12b:free", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
        .init(id: "openai/gpt-4o", spec: .init(contextWindowSize: 128_000, supportsVision: true, supportsTools: true)),
        .init(id: "openai/gpt-5", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
        .init(id: "openai/gpt-5-mini", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
        .init(id: "openai/gpt-oss-20b:free", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
        .init(id: "qwen/qwen3.6-plus", spec: .init(contextWindowSize: 1_000_000, supportsVision: false, supportsTools: true)),
        .init(id: "stepfun/step-3.5-flash:free", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
        .init(id: "z-ai/glm-4.5-air:free", spec: .init(contextWindowSize: 128_000, supportsVision: false, supportsTools: true)),
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
