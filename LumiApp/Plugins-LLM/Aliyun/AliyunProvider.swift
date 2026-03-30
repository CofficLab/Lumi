import Foundation
import MagicKit
import os

// MARK: - 阿里云供应商

/// 阿里云 DashScope 供应商实现
///
/// 提供通义千问、GLM、MiniMax、Kimi 等大模型服务。
/// API 地址：https://coding.dashscope.aliyuncs.com/apps/anthropic
/// 兼容 Anthropic API 格式。
final class AliyunProvider: NSObject, SuperLLMProvider, SuperLog, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "llm.aliyun")
    nonisolated static let emoji = "🔵"
    nonisolated static let verbose = true

    // MARK: - 基础信息

    static let id = "aliyun"
    static let displayName = String(localized: "阿里云 CodingPlan", table: "Aliyun")
    static let iconName = "cloud.fill"
    static let description = String(localized: "阿里云 DashScope Coding Plan（兼容 Anthropic API）", table: "Aliyun")

    // MARK: - 配置相关

    static let apiKeyStorageKey = "DevAssistant_ApiKey_Aliyun"
    static let modelStorageKey = "DevAssistant_Model_Aliyun"
    static let defaultModel = "qwen3.5-plus"

    static let availableModels = [
        "qwen3.5-plus",
        "glm-4.7",
        "glm-5",
        "MiniMax-M2.5",
        "kimi-k2.5",
    ]

    // MARK: - SuperLLMProvider

    override init() {
        super.init()
    }

    var baseURL: String {
        "https://coding.dashscope.aliyuncs.com/apps/anthropic/v1/messages"
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
        let systemMessage = messages.first(where: { $0.role == .system })?.content ?? systemPrompt
        let conversationMessages = messages
            .filter { $0.role.shouldSendToLLM }
            .map { transformMessage($0) }

        var body: [String: Any] = [
            "model": model,
            "max_tokens": 8192,
            "system": systemMessage,
            "messages": conversationMessages,
        ]

        if let tools = tools, !tools.isEmpty {
            body["tools"] = tools.map { formatTool($0) }
        }

        return body
    }

    func parseResponse(data: Data) throws -> (content: String, toolCalls: [ToolCall]?) {
        let result = try JSONDecoder().decode(AliyunResponse.self, from: data)

        var textContent = ""
        var toolCalls: [ToolCall] = []

        for item in result.content {
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
    /// Aliyun 兼容 Anthropic 流式格式：
    /// event: content_block_delta
    /// data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}
    func parseStreamChunk(data: Data) throws -> StreamChunk? {
        guard let text = String(data: data, encoding: .utf8) else {
            return nil
        }

        var eventType: String?
        var eventDataLines: [String] = []

        let lines = text.components(separatedBy: "\n")
        for line in lines {
            if line.hasPrefix("event:") {
                let afterPrefix = String(line.dropFirst(6))
                eventType = afterPrefix.trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                let afterPrefix = String(line.dropFirst(5))
                eventDataLines.append(afterPrefix.trimmingCharacters(in: .whitespaces))
            }
        }

        let dataStr = eventDataLines.isEmpty ? nil : eventDataLines.joined(separator: "\n")
        guard let dataStr = dataStr, !dataStr.isEmpty else {
            return nil
        }

        guard let jsonData = dataStr.data(using: .utf8) else {
            return nil
        }

        do {
            let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            let jsonType = json?["type"] as? String
            let effectiveEventType = eventType ?? jsonType ?? "unknown"

            // 处理错误
            if let error = json?["error"] as? [String: Any],
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
                if let message = json?["message"] as? [String: Any],
                   let usage = message["usage"] as? [String: Any] {
                    inputTokens = usage["input_tokens"] as? Int
                }
                return StreamChunk(eventType: .messageStart, rawEvent: text, inputTokens: inputTokens)
            }

            // 处理消息增量
            if effectiveEventType == "message_delta" {
                let stopReason = (json?["delta"] as? [String: Any])?["stop_reason"] as? String ?? json?["stop_reason"] as? String
                var inputTokens: Int?
                var outputTokens: Int?
                if let usage = json?["usage"] as? [String: Any] {
                    inputTokens = usage["input_tokens"] as? Int
                    outputTokens = usage["output_tokens"] as? Int
                }
                return StreamChunk(eventType: .messageDelta, rawEvent: text, inputTokens: inputTokens, outputTokens: outputTokens, stopReason: stopReason)
            }

            // 处理消息结束
            if effectiveEventType == "message_stop" {
                return StreamChunk(isDone: true, eventType: .messageStop, rawEvent: text)
            }

            // 处理内容块开始
            if effectiveEventType == "content_block_start" {
                if let contentBlock = json?["content_block"] as? [String: Any],
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

                    return StreamChunk(eventType: .contentBlockStart, rawEvent: text)
                }
                return StreamChunk(eventType: .contentBlockStart, rawEvent: text)
            }

            // 处理内容块增量
            if effectiveEventType == "content_block_delta" {
                if let delta = json?["delta"] as? [String: Any] {
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
            if Self.verbose {
                Self.logger.warning("解析流式数据块失败: \(error.localizedDescription)")
            }
            return StreamChunk(error: "解析失败: \(error.localizedDescription)", eventType: .unknown, rawEvent: text)
        }
    }

    static var logEmoji: String { "🔵" }
}

// MARK: - 消息转换

extension AliyunProvider {
    func transformMessage(_ message: ChatMessage) -> [String: Any] {
        if let toolCallID = message.toolCallID {
            return [
                "role": "user",
                "content": [
                    ["type": "tool_result", "tool_use_id": toolCallID, "content": message.content],
                ],
            ]
        }

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

        if !message.images.isEmpty {
            if Self.verbose {
                Self.logger.info("\(self.t) 消息包含 \(message.images.count) 张图片，正在转换...")
            }

            var content: [[String: Any]] = []

            if !message.content.isEmpty {
                content.append(["type": "text", "text": message.content])
            }

            for (index, image) in message.images.enumerated() {
                let base64Data = image.data.base64EncodedString()
                if Self.verbose {
                    Self.logger.info("\(self.t) 图片 \(index + 1): \(image.mimeType), base64长度: \(base64Data.count)")
                }
                content.append([
                    "type": "image",
                    "source": ["type": "base64", "media_type": image.mimeType, "data": base64Data]
                ])
            }

            if Self.verbose {
                Self.logger.info("\(self.t) 已将 \(message.images.count) 张图片转换为 API 格式")
            }

            return ["role": message.role.rawValue, "content": content]
        }

        if message.content.contains("[IMAGE_BASE64:") {
            var content: [[String: Any]] = []
            let components = message.content.components(separatedBy: "[IMAGE_BASE64:")

            if !components[0].isEmpty {
                content.append(["type": "text", "text": components[0]])
            }

            for component in components.dropFirst() {
                if let closeBracketIndex = component.firstIndex(of: "]") {
                    let imagePart = component[..<closeBracketIndex]
                    let textPart = component[component.index(after: closeBracketIndex)...]

                    let imageComponents = imagePart.split(separator: ":", maxSplits: 1)
                    if imageComponents.count == 2 {
                        let mimeType = String(imageComponents[0])
                        let base64Data = String(imageComponents[1])
                        content.append([
                            "type": "image",
                            "source": ["type": "base64", "media_type": mimeType, "data": base64Data]
                        ])
                    }

                    if !textPart.isEmpty {
                        let cleanText = String(textPart).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !cleanText.isEmpty {
                            content.append(["type": "text", "text": cleanText])
                        }
                    }
                }
            }

            return ["role": message.role.rawValue, "content": content]
        }

        return ["role": message.role.rawValue, "content": message.content]
    }
}

// MARK: - 工具格式

extension AliyunProvider {
    func formatTool(_ tool: AgentTool) -> [String: Any] {
        ["name": tool.name, "description": tool.description, "input_schema": tool.inputSchema]
    }
}