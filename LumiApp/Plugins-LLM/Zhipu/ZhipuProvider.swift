import Foundation
import MagicKit
import os

// MARK: - Zhipu AI 供应商

/// Zhipu AI (智谱 AI) API 供应商实现
///
/// Zhipu AI 提供了兼容 Anthropic 的 API 接口。
final class ZhipuProvider: NSObject, SuperLLMProvider, SuperLog, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "llm.zhipu")
    nonisolated static let emoji = "🔴"
    nonisolated static let verbose = true

    // MARK: - 基础信息

    static let id = "zhipu"
    static let displayName = String(localized: "Zhipu AI CodingPlan", table: "Zhipu")
    static let iconName = "sparkles"
    static let description = String(localized: "智谱 AI (GLM)", table: "Zhipu")

    // MARK: - 配置相关

    static let apiKeyStorageKey = "DevAssistant_ApiKey_Zhipu"
    static let modelStorageKey = "DevAssistant_Model_Zhipu"

    static let defaultModel = "glm-4.7"

    static let availableModels = [
        "glm-5",
        "glm-4.7",
        "glm-4.6",
        "glm-4.5-air",
    ]

    // MARK: - SuperLLMProvider

    override init() {
        super.init()
    }

    var baseURL: String {
        "https://open.bigmodel.cn/api/anthropic/v1/messages"
    }

    func buildRequest(url: URL, apiKey: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    func buildRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [AgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any] {
        // Zhipu 兼容 Anthropic 格式
        let systemParts = messages
            .filter { $0.role == .system }
            .map { $0.content.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let systemMessage: String
        if !systemParts.isEmpty {
            systemMessage = systemParts.joined(separator: "\n\n")
        } else {
            systemMessage = systemPrompt
        }

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
        // Zhipu 响应格式与 Anthropic 兼容
        struct AnthropicResponse: Decodable {
            struct Content: Decodable {
                let type: String
                let text: String?
                let id: String?
                let name: String?
                let input: [String: AnySendable]?

                enum CodingKeys: String, CodingKey {
                    case type, text, id, name, input
                }
            }

            let content: [Content]
        }

        let result = try JSONDecoder().decode(AnthropicResponse.self, from: data)

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
    /// Zhipu 兼容 Anthropic 流式格式
    func parseStreamChunk(data: Data) throws -> StreamChunk? {
        // 先按 Anthropic SSE 解析（Zhipu 官方兼容路径）
        let anthropicProvider = AnthropicProvider()
        if let chunk = try anthropicProvider.parseStreamChunk(data: data) {
            // Anthropic 解析器在 JSON 格式异常时会返回 error chunk。
            // 对 GLM-5 做一次回退尝试，避免单个坏包导致整轮失败。
            if chunk.error != nil {
                let openAIProvider = OpenAIProvider()
                if let fallback = try? openAIProvider.parseStreamChunk(data: data) {
                    if Self.verbose {
                        Self.logger.info("\(self.t) 流解析回退到 OpenAI 格式成功")
                    }
                    return fallback
                }

                // 无法回退解析时，忽略该坏包，等待下一个 chunk。
                // 这样可以提升对非标准分包的容错，不会直接中断整轮请求。
                if Self.verbose {
                    let raw = String(data: data, encoding: .utf8) ?? "<binary>"
                    Self.logger.warning("\(self.t) 忽略不可解析的流式分包: \(raw.prefix(200))")
                }
                return nil
            }
            return chunk
        }

        // Anthropic 返回 nil 时，尝试 OpenAI 兼容格式
        let openAIProvider = OpenAIProvider()
        if let fallback = try? openAIProvider.parseStreamChunk(data: data) {
            if Self.verbose {
                Self.logger.info("\(self.t) 流解析使用 OpenAI 兼容格式")
            }
            return fallback
        }

        return nil
    }

    static var logEmoji: String { "🔴" }
}

// MARK: - 消息转换

extension ZhipuProvider {
    func transformMessage(_ message: ChatMessage) -> [String: Any] {
        // 工具结果消息
        if let toolCallID = message.toolCallID {
            return [
                "role": "user",
                "content": [
                    [
                        "type": "tool_result",
                        "tool_use_id": toolCallID,
                        "content": message.content,
                    ],
                ],
            ]
        }

        // 带工具调用的助手消息
        if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
            var content: [[String: Any]] = []

            if !message.content.isEmpty {
                content.append([
                    "type": "text",
                    "text": message.content,
                ])
            }

            for tc in toolCalls {
                // 确保 input 始终是一个有效的字典
                let inputObject: [String: Any]
                if let data = tc.arguments.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    inputObject = json
                } else {
                    inputObject = [:]
                }

                content.append([
                    "type": "tool_use",
                    "id": tc.id,
                    "name": tc.name,
                    "input": inputObject,
                ])
            }

            return [
                "role": "assistant",
                "content": content,
            ]
        }

        // Handle images in message
        if !message.images.isEmpty {
            if Self.verbose {
                Self.logger.info("\(self.t) 消息包含 \(message.images.count) 张图片，正在转换...")
            }

            var content: [[String: Any]] = []

            // Add text content first (if not empty)
            if !message.content.isEmpty {
                content.append([
                    "type": "text",
                    "text": message.content
                ])
            }

            // Add all images
            for (index, image) in message.images.enumerated() {
                let base64Data = image.data.base64EncodedString()
                if Self.verbose {
                    Self.logger.info("\(self.t) 图片 \(index + 1): \(image.mimeType), base64长度: \(base64Data.count)")
                }
                content.append([
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": image.mimeType,
                        "data": base64Data
                    ]
                ])
            }

            if Self.verbose {
                Self.logger.info("\(self.t) 已将 \(message.images.count) 张图片转换为 API 格式")
            }

            return [
                "role": message.role.rawValue,
                "content": content
            ]
        }

        // Fallback for legacy marker format (backward compatibility)
        // Marker format: [IMAGE_BASE64:<mime_type>:<data>]
        if message.content.contains("[IMAGE_BASE64:") {
            var content: [[String: Any]] = []
            let components = message.content.components(separatedBy: "[IMAGE_BASE64:")

            // First component is text before any image
            if !components[0].isEmpty {
                content.append([
                    "type": "text",
                    "text": components[0]
                ])
            }

            for component in components.dropFirst() {
                // component format: <mime_type>:<data>]<rest_of_text>
                if let closeBracketIndex = component.firstIndex(of: "]") {
                    let imagePart = component[..<closeBracketIndex]
                    let textPart = component[component.index(after: closeBracketIndex)...]

                    let imageComponents = imagePart.split(separator: ":", maxSplits: 1)
                    if imageComponents.count == 2 {
                        let mimeType = String(imageComponents[0])
                        let base64Data = String(imageComponents[1])

                        content.append([
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": mimeType,
                                "data": base64Data
                            ]
                        ])
                    }

                    if !textPart.isEmpty {
                        // Clean up newlines that might have been added
                        let cleanText = String(textPart).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !cleanText.isEmpty {
                            content.append([
                                "type": "text",
                                "text": cleanText
                            ])
                        }
                    }
                }
            }

            return [
                "role": message.role.rawValue,
                "content": content
            ]
        }

        return [
            "role": message.role.rawValue,
            "content": message.content,
        ]
    }
}

// MARK: - 工具格式

extension ZhipuProvider {
    func formatTool(_ tool: AgentTool) -> [String: Any] {
        [
            "name": tool.name,
            "description": tool.description,
            "input_schema": tool.inputSchema,
        ]
    }
}
