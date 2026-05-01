import Foundation
import MagicKit
import os

/// Xiaomi API 供应商实现
///
/// 集成 Xiaomi 大模型服务，兼容 OpenAI API 格式。
final class XiaomiProvider: NSObject, SuperLLMProvider, SuperLog, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "llm.xiaomi")
    nonisolated static let emoji = "🟡"
    nonisolated static let verbose: Bool = false

    // MARK: - 基础信息

    static let id = "xiaomi"
    static let displayName = String(localized: "Xiaomi", table: "Xiaomi")
    static let description = String(localized: "Xiaomi AI Models", table: "Xiaomi")

    // MARK: - 配置相关

    static let apiKeyStorageKey = "DevAssistant_ApiKey_Xiaomi"
    static let defaultModel = "mimo-v2.5-pro"

    static let modelCatalog: [LLMModelCatalogItem] = [
        .init(id: "mimo-v2.5-pro", spec: .init(contextWindowSize: 1_000_000, supportsVision: false, supportsTools: true)),
        .init(id: "mimo-v2.5", spec: .init(contextWindowSize: 1_000_000, supportsVision: false, supportsTools: true)),
        .init(id: "mimo-v2-pro", spec: .init(contextWindowSize: 1_000_000, supportsVision: false, supportsTools: true)),
        .init(id: "mimo-v2-omni", spec: .init(contextWindowSize: 256_000, supportsVision: true, supportsTools: true)),
        .init(id: "mimo-v2.5-tts", spec: .init(contextWindowSize: 8_000, supportsVision: false, supportsTools: false)),
        .init(id: "mimo-v2.5-tts-voiceclone", spec: .init(contextWindowSize: 8_000, supportsVision: false, supportsTools: false)),
        .init(id: "mimo-v2.5-tts-voicedesign", spec: .init(contextWindowSize: 8_000, supportsVision: false, supportsTools: false)),
        .init(id: "mimo-v2-tts", spec: .init(contextWindowSize: 8_000, supportsVision: false, supportsTools: false)),
    ]

    // MARK: - SuperLLMProvider

    override init() {
        super.init()
    }

    var baseURL: String {
        "https://token-plan-cn.xiaomimimo.com/v1/chat/completions"
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
        tools: [SuperAgentTool]?,
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
        let result = try JSONDecoder().decode(XiaomiResponse.self, from: data)

        guard let choiceMessage = result.choices.first?.message else {
            throw NSError(domain: "XiaomiProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "No choices in response"])
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
        tools: [SuperAgentTool]?,
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
    /// Xiaomi SSE 格式（兼容 OpenAI）：
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

                if let toolCalls = delta["tool_calls"] as? [[String: Any]] {
                    var resultToolCalls: [ToolCall] = []
                    var partialJson: String?

                    for tc in toolCalls {
                        guard let function = tc["function"] as? [String: Any] else {
                            continue
                        }

                        let id = tc["id"] as? String
                        let name = function["name"] as? String
                        let arguments = function["arguments"] as? String

                        if let toolId = id, let toolName = name {
                            let toolCall = ToolCall(id: toolId, name: toolName, arguments: arguments ?? "{}")
                            resultToolCalls.append(toolCall)
                        }

                        if let args = arguments {
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

            return nil
        } catch {
            if Self.verbose {
                Self.logger.error("解析流式数据块失败: \(error.localizedDescription)")
            }
            return nil
        }
    }
}

// MARK: - 消息转换

extension XiaomiProvider {
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

extension XiaomiProvider {
    func formatTool(_ tool: SuperAgentTool) -> [String: Any] {
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
