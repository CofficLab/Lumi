import Foundation
import MagicKit
import OSLog

// MARK: - Zhipu AI 供应商

/// Zhipu AI (智谱 AI) API 供应商实现
///
/// Zhipu AI 提供了兼容 Anthropic 的 API 接口。
struct ZhipuProvider: LLMProviderProtocol, SuperLog {
    nonisolated static let emoji = "🔴"
    nonisolated static let verbose = true

    // MARK: - 基础信息

    static let id = "zhipu"
    static let displayName = "Zhipu AI"
    static let iconName = "character.book.ja"
    static let description = "智谱 AI (GLM)"

    // MARK: - 配置相关

    static let apiKeyStorageKey = "DevAssistant_ApiKey_Zhipu"
    static let modelStorageKey = "DevAssistant_Model_Zhipu"

    static let defaultModel = "glm-4.7"

    static let availableModels = [
        "glm-4.7",
        "glm-4.6",
        "glm-4.5-air",
    ]

    // MARK: - LLMProviderProtocol

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
        let systemMessage = messages.first(where: { $0.role == .system })?.content ?? systemPrompt

        let conversationMessages = messages
            .filter { $0.role != .system }
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
                let argsObject: Any
                if let data = tc.arguments.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) {
                    argsObject = json
                } else {
                    argsObject = [:]
                }

                content.append([
                    "type": "tool_use",
                    "id": tc.id,
                    "name": tc.name,
                    "input": argsObject,
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
                os_log("\(Self.t)🖼️ 消息包含 \(message.images.count) 张图片，正在转换...")
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
                    os_log("\(Self.t)  图片 \(index + 1): \(image.mimeType), base64长度: \(base64Data.count)")
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
                os_log("\(Self.t)✅ 已将 \(message.images.count) 张图片转换为 API 格式")
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
