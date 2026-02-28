import Foundation
import OSLog
import MagicKit

// MARK: - Anthropic Provider

struct AnthropicProvider: LLMProviderProtocol, SuperLog {
    
    nonisolated static let verbose = true

    // MARK: - Basic Info

    static let id = "anthropic"
    static let displayName = "Anthropic"
    static let iconName = "brain.head.profile"
    static let description = "Claude AI by Anthropic"

    // MARK: - Configuration

    static let apiKeyStorageKey = "DevAssistant_ApiKey_Anthropic"
    static let modelStorageKey = "DevAssistant_Model_Anthropic"

    static let defaultModel = "claude-sonnet-4-20250514"

    static let availableModels = [
        "claude-sonnet-4-20250514",
        "claude-opus-4-20250514",
        "claude-3-5-sonnet-20241022",
        "claude-3-5-sonnet-20240620",
        "claude-3-opus-20240229",
        "claude-3-sonnet-20240229",
        "claude-3-haiku-20240307",
    ]

    // MARK: - LLMProviderProtocol

    var baseURL: String {
        "https://api.anthropic.com/v1/messages"
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
    
    // MARK: - Message Transformation
    
    func transformMessage(_ message: ChatMessage) -> [String: Any] {
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

    func parseResponse(data: Data) throws -> (content: String, toolCalls: [ToolCall]?) {
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

    static var logEmoji: String { "🟣" }
}

// MARK: - Tool Formatting

extension AnthropicProvider {
    func formatTool(_ tool: AgentTool) -> [String: Any] {
        [
            "name": tool.name,
            "description": tool.description,
            "input_schema": tool.inputSchema,
        ]
    }
}

// MARK: - Helper Types

struct AnySendable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(Int.self) { value = x }
        else if let x = try? container.decode(Double.self) { value = x }
        else if let x = try? container.decode(String.self) { value = x }
        else if let x = try? container.decode(Bool.self) { value = x }
        else if let x = try? container.decode([String: AnySendable].self) { value = x.mapValues { $0.value } }
        else if let x = try? container.decode([AnySendable].self) { value = x.map { $0.value } }
        else { value = "" }
    }

    init(value: Any) {
        self.value = value
    }
}
