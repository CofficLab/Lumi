import Foundation
import MagicKit
import OSLog

// MARK: - 阿里云供应商

/// 阿里云 DashScope 供应商实现
///
/// 提供通义千问、GLM、MiniMax、Kimi 等大模型服务
/// API 地址：https://coding.dashscope.aliyuncs.com/apps/anthropic
/// 兼容 Anthropic API 格式
struct AliyunProvider: SuperLLMProvider, SuperLog {
    nonisolated static let emoji = "🔵"
    nonisolated static let verbose = true

    // MARK: - 基础信息

    static let id = "aliyun"
    static let displayName = "阿里云"
    static let iconName = "cloud.fill"
    static let description = "通义千问、GLM、MiniMax、Kimi 等大模型"

    // MARK: - 配置相关

    static let apiKeyStorageKey = "DevAssistant_ApiKey_Aliyun"
    static let modelStorageKey = "DevAssistant_Model_Aliyun"

    static let defaultModel = "qwen3.5-plus"

    static let availableModels = [
        "qwen3.5-plus",       // 通义千问 3.5 Plus
        "glm-4.7",            // GLM-4.7
        "glm-5",              // GLM-5
        "MiniMax-M2.5",       // MiniMax M2.5
        "kimi-k2.5",          // Kimi K2.5
    ]

    // MARK: - LLMProviderProtocol

    var baseURL: String {
        "https://coding.dashscope.aliyuncs.com/apps/anthropic/v1/messages"
    }

    func buildRequest(url: URL, apiKey: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // 阿里云 Coding Plan 使用 Authorization: Bearer <API Key> 格式
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
        // 阿里云兼容 Anthropic 格式
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
        // 阿里云响应格式与 Anthropic 兼容
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

                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    type = try container.decode(String.self, forKey: .type)
                    text = try container.decodeIfPresent(String.self, forKey: .text)
                    id = try container.decodeIfPresent(String.self, forKey: .id)
                    name = try container.decodeIfPresent(String.self, forKey: .name)
                    if let inputContainer = try? container.decodeIfPresent([String: AnySendable].self, forKey: .input) {
                        input = inputContainer.mapValues { v in AnySendable(value: v.value) }
                    } else {
                        input = nil
                    }
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
    /// Aliyun 兼容 Anthropic 流式格式
    func parseStreamChunk(data: Data) throws -> StreamChunk? {
        // 复用 Anthropic 的解析逻辑
        let anthropicProvider = AnthropicProvider()
        return try anthropicProvider.parseStreamChunk(data: data)
    }

    static var logEmoji: String { "🔵" }
}

// MARK: - 消息转换

extension AliyunProvider {
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

        // 处理消息中的图片
        if !message.images.isEmpty {
            if Self.verbose {
                os_log("\(Self.t)🖼️ 消息包含 \(message.images.count) 张图片，正在转换...")
            }

            var content: [[String: Any]] = []

            // 先添加文本内容（如果非空）
            if !message.content.isEmpty {
                content.append([
                    "type": "text",
                    "text": message.content
                ])
            }

            // 添加所有图片
            for (index, image) in message.images.enumerated() {
                let base64Data = image.data.base64EncodedString()
                if Self.verbose {
                    os_log("\(Self.t)  图片 \(index + 1): \(image.mimeType), base64 长度：\(base64Data.count)")
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

        // 兼容旧版 marker 格式
        // Marker 格式：[IMAGE_BASE64:<mime_type>:<data>]
        if message.content.contains("[IMAGE_BASE64:") {
            var content: [[String: Any]] = []
            let components = message.content.components(separatedBy: "[IMAGE_BASE64:")

            // 第一个组件是图片之前的文本
            if !components[0].isEmpty {
                content.append([
                    "type": "text",
                    "text": components[0]
                ])
            }

            for component in components.dropFirst() {
                // component 格式：<mime_type>:<data>]<rest_of_text>
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
                        // 清理可能添加的换行符
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

extension AliyunProvider {
    func formatTool(_ tool: AgentTool) -> [String: Any] {
        [
            "name": tool.name,
            "description": tool.description,
            "input_schema": tool.inputSchema,
        ]
    }
}
