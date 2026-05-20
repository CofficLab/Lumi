import Foundation

/// Anthropic 兼容供应商适配器
///
/// 支持 Anthropic API 格式的供应商，包括：
/// - Anthropic 原生 API
/// - 阿里云 DashScope（兼容 Anthropic 格式）
///
/// ## API 特性
///
/// - 认证方式: `x-api-key` 请求头
/// - System Prompt: 顶层 `system` 字段
/// - 流式格式: 事件驱动 SSE（`event:` + `data:`）
/// - 响应结构: `content` 数组，包含 `text` 和 `tool_use` 块
public struct AnthropicCompatibleProviderAdapter: Sendable {
    public let configuration: AnthropicCompatibleProviderConfiguration

    public init(configuration: AnthropicCompatibleProviderConfiguration) {
        self.configuration = configuration
    }

    // MARK: - 请求构建

    /// 构建 HTTP 请求
    public func buildRequest(url: URL, apiKey: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue(configuration.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        for (field, value) in configuration.additionalHeaders {
            request.addValue(value, forHTTPHeaderField: field)
        }

        return request
    }

    /// 构建非流式请求体
    public func buildRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [any LLMToolSchemaProviding]?,
        systemPrompt: String
    ) throws -> [String: Any] {
        // 合并所有 system 消息
        let systemParts = messages
            .filter { $0.role == .system }
            .map(\.content)
            .filter { !$0.isEmpty }
        let systemMessage = systemParts.isEmpty
            ? systemPrompt
            : systemParts.joined(separator: "\n\n")

        let conversationMessages = messages
            .filter { $0.role != .system }
            .map { transformMessage($0) }

        var body: [String: Any] = [
            "model": model,
            "max_tokens": configuration.defaultMaxTokens,
            "system": systemMessage,
            "messages": conversationMessages,
        ]

        if let tools, !tools.isEmpty {
            body["tools"] = tools.map(formatTool)
        }

        return body
    }

    /// 构建流式请求体
    public func buildStreamingRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [any LLMToolSchemaProviding]?,
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

    // MARK: - 响应解析

    /// 解析非流式响应
    public func parseResponse(data: Data) throws -> (content: String, toolCalls: [ToolCall]?) {
        if let errorResponse = try? JSONDecoder().decode(AnthropicCompatibleErrorResponse.self, from: data) {
            throw AnthropicCompatibleProviderError.apiError(message: errorResponse.error.message)
        }

        let response = try JSONDecoder().decode(AnthropicCompatibleResponse.self, from: data)

        var textContent = ""
        var toolCalls: [ToolCall] = []

        for item in response.content {
            if item.type == "text", let text = item.text {
                textContent += text
            } else if item.type == "tool_use",
                      let id = item.id,
                      let name = item.name,
                      let inputDict = item.input {
                let normalDict = inputDict.mapValues { $0.value }
                let inputData = try JSONSerialization.data(withJSONObject: normalDict)
                let inputString = String(data: inputData, encoding: .utf8) ?? "{}"
                toolCalls.append(ToolCall(id: id, name: name, arguments: inputString))
            }
        }

        return (textContent, toolCalls.isEmpty ? nil : toolCalls)
    }

    // MARK: - 流式解析

    /// 解析流式响应数据块
    ///
    /// Anthropic SSE 格式：
    /// ```
    /// event: content_block_delta
    /// data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}
    /// ```
    public func parseStreamChunk(data: Data) throws -> StreamChunk? {
        guard let text = String(data: data, encoding: .utf8) else {
            return nil
        }

        var eventType: String?
        var eventDataLines: [String] = []

        let lines = text.components(separatedBy: "\n")
        for line in lines {
            if line.hasPrefix("event:") {
                eventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                eventDataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
            }
        }

        let dataStr = eventDataLines.isEmpty ? nil : eventDataLines.joined(separator: "\n")
        guard let dataStr, !dataStr.isEmpty else {
            return nil
        }

        guard let jsonData = dataStr.data(using: .utf8) else {
            return nil
        }

        do {
            guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                return nil
            }

            let jsonType = json["type"] as? String
            let effectiveEventType = eventType ?? jsonType ?? "unknown"

            // 处理错误
            if let error = json["error"] as? [String: Any],
               let errorMessage = error["message"] as? String {
                return StreamChunk(error: errorMessage, eventType: .unknown, rawEvent: text)
            }

            // 处理 ping 事件
            if effectiveEventType == "ping" {
                return StreamChunk(eventType: .ping, rawEvent: text)
            }

            // 处理消息开始
            if effectiveEventType == "message_start" {
                var inputTokens: Int?
                if let message = json["message"] as? [String: Any],
                   let usage = message["usage"] as? [String: Any] {
                    inputTokens = usage["input_tokens"] as? Int
                }
                return StreamChunk(eventType: .messageStart, rawEvent: text, inputTokens: inputTokens)
            }

            // 处理消息增量
            if effectiveEventType == "message_delta" {
                let stopReason = (json["delta"] as? [String: Any])?["stop_reason"] as? String
                    ?? json["stop_reason"] as? String
                var inputTokens: Int?
                var outputTokens: Int?
                if let usage = json["usage"] as? [String: Any] {
                    inputTokens = usage["input_tokens"] as? Int
                    outputTokens = usage["output_tokens"] as? Int
                }
                return StreamChunk(
                    eventType: .messageDelta,
                    rawEvent: text,
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    stopReason: stopReason
                )
            }

            // 处理消息结束
            if effectiveEventType == "message_stop" {
                return StreamChunk(isDone: true, eventType: .messageStop, rawEvent: text)
            }

            // 处理内容块开始
            if effectiveEventType == "content_block_start" {
                if let contentBlock = json["content_block"] as? [String: Any],
                   let blockType = contentBlock["type"] as? String {

                    if blockType == "thinking" {
                        return StreamChunk(eventType: .contentBlockStart, rawEvent: text)
                    }

                    if blockType == "tool_use" {
                        if let id = contentBlock["id"] as? String,
                           let name = contentBlock["name"] as? String {
                            let toolCall = ToolCall(id: id, name: name, arguments: "{}")
                            return StreamChunk(toolCalls: [toolCall], eventType: .contentBlockStart, rawEvent: text)
                        }
                    }

                    if blockType == "text" {
                        if let textContent = contentBlock["text"] as? String, !textContent.isEmpty {
                            return StreamChunk(content: textContent, eventType: .contentBlockStart, rawEvent: text)
                        }
                        return StreamChunk(eventType: .contentBlockStart, rawEvent: text)
                    }
                }
                return StreamChunk(eventType: .contentBlockStart, rawEvent: text)
            }

            // 处理内容块增量
            if effectiveEventType == "content_block_delta" {
                if let delta = json["delta"] as? [String: Any] {
                    if let thinkingDelta = delta["thinking_delta"] as? String {
                        return StreamChunk(content: thinkingDelta, eventType: .thinkingDelta, rawEvent: text)
                    }
                    if let thinkingDelta = delta["thinking"] as? String {
                        return StreamChunk(content: thinkingDelta, eventType: .thinkingDelta, rawEvent: text)
                    }
                    if let textContent = delta["text"] as? String {
                        return StreamChunk(content: textContent, eventType: .textDelta, rawEvent: text)
                    }
                    if let textDelta = delta["text_delta"] as? String {
                        return StreamChunk(content: textDelta, eventType: .textDelta, rawEvent: text)
                    }
                    if let partialJson = delta["partial_json"] as? String {
                        return StreamChunk(partialJson: partialJson, eventType: .inputJsonDelta, rawEvent: text)
                    }
                    if delta["signature"] != nil {
                        return StreamChunk(eventType: .signatureDelta, rawEvent: text)
                    }
                    return StreamChunk(eventType: .contentBlockDelta, rawEvent: text)
                }
                return StreamChunk(eventType: .contentBlockDelta, rawEvent: text)
            }

            // 处理内容块停止
            if effectiveEventType == "content_block_stop" {
                return StreamChunk(eventType: .contentBlockStop, rawEvent: text)
            }

            return StreamChunk(eventType: .unknown, rawEvent: text)
        } catch {
            return StreamChunk(
                error: "解析失败: \(error.localizedDescription)",
                eventType: .unknown,
                rawEvent: text
            )
        }
    }

    // MARK: - 消息转换

    /// 将 ChatMessage 转换为 Anthropic API 格式
    public func transformMessage(_ message: ChatMessage) -> [String: Any] {
        // 工具结果消息
        if let toolCallID = message.toolCallID {
            return [
                "role": "user",
                "content": [
                    ["type": "tool_result", "tool_use_id": toolCallID, "content": message.content],
                ],
            ]
        }

        // 包含工具调用的 assistant 消息
        if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
            var content: [[String: Any]] = []

            if !message.content.isEmpty {
                content.append(["type": "text", "text": message.content])
            }

            for tc in toolCalls {
                let inputObject: [String: Any]
                if let data = tc.arguments.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    inputObject = json
                } else {
                    inputObject = [:]
                }
                content.append(["type": "tool_use", "id": tc.id, "name": tc.name, "input": inputObject])
            }

            return ["role": "assistant", "content": content]
        }

        // 普通文本消息
        return ["role": message.role.rawValue, "content": message.content]
    }

    // MARK: - 工具格式

    /// 将工具转换为 Anthropic API 格式
    public func formatTool(_ tool: any LLMToolSchemaProviding) -> [String: Any] {
        [
            "name": tool.name,
            "description": tool.toolDescription,
            "input_schema": tool.inputSchema,
        ]
    }

}
