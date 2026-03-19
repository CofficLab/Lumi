import Foundation
import MagicKit
import os

// MARK: - Anthropic Provider

/// Anthropic Claude 供应商实现
///
/// 集成 Anthropic 的 Claude AI 模型。
/// 支持完整的 Tool Calls 功能和图片输入。
///
/// ## 支持的模型
///
/// | 模型 ID | 说明 | 发布时间 |
/// |---------|------|----------|
/// | claude-sonnet-4-20250514 | Claude 4 Sonnet (最新) | 2025-05 |
/// | claude-opus-4-20250514 | Claude 4 Opus (最强) | 2025-05 |
/// | claude-3-5-sonnet-20241022 | Claude 3.5 Sonnet | 2024-10 |
/// | claude-3-5-sonnet-20240620 | Claude 3.5 Sonnet | 2024-06 |
/// | claude-3-opus-20240229 | Claude 3 Opus | 2024-02 |
/// | claude-3-sonnet-20240229 | Claude 3 Sonnet | 2024-02 |
/// | claude-3-haiku-20240307 | Claude 3 Haiku (最快) | 2024-03 |
///
/// ## API 特性
///
/// - 认证方式: `x-api-key` 请求头
/// - API 版本: `anthropic-version` 请求头 (2023-06-01)
/// - 最大输出: 8192 tokens
/// - 支持 Tool Calls: ✅
/// - 支持图片输入: ✅ (base64 编码)
final class AnthropicProvider: NSObject, SuperLLMProvider, SuperLog, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "llm.anthropic")
    nonisolated static let emoji = "🤖"
    
    /// 是否启用详细日志
    nonisolated static let verbose = true

    // MARK: - Basic Info

    /// 供应商唯一标识符
    static let id = "anthropic"
    
    /// 显示名称
    static let displayName = "Anthropic"
    
    /// 图标名称 (SF Symbol)
    static let iconName = "brain.head.profile"
    
    /// 供应商描述
    static let description = "Claude AI by Anthropic"

    // MARK: - Configuration

    /// API Key 存储键名
    static let apiKeyStorageKey = "DevAssistant_ApiKey_Anthropic"
    
    /// 模型选择存储键名
    static let modelStorageKey = "DevAssistant_Model_Anthropic"

    /// 默认模型
    static let defaultModel = "claude-sonnet-4-20250514"

    /// 可用模型列表
    static let availableModels = [
        "claude-sonnet-4-20250514",
        "claude-opus-4-20250514",
        "claude-3-5-sonnet-20241022",
        "claude-3-5-sonnet-20240620",
        "claude-3-opus-20240229",
        "claude-3-sonnet-20240229",
        "claude-3-haiku-20240307",
    ]

    // MARK: - SuperLLMProvider

    override init() {
        super.init()
    }

    /// API 基础 URL
    var baseURL: String {
        "https://api.anthropic.com/v1/messages"
    }

    /// 构建 API 请求
    ///
    /// 配置 Anthropic API 所需的请求头：
    /// - `x-api-key`: API 密钥认证
    /// - `anthropic-version`: API 版本
    /// - `Content-Type`: 请求内容类型
    ///
    /// - Parameters:
    ///   - url: 请求 URL
    ///   - apiKey: API 密钥
    /// - Returns: 配置好的 URLRequest
    func buildRequest(url: URL, apiKey: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    /// 构建请求体
    ///
    /// 将消息转换为 Anthropic API 格式：
    /// - 提取系统消息到单独的 "system" 字段
    /// - 转换对话消息格式
    /// - 添加工具定义（如果提供）
    ///
    /// - Parameters:
    ///   - messages: 消息列表
    ///   - model: 模型名称
    ///   - tools: 可用工具列表
    ///   - systemPrompt: 系统提示词
    /// - Returns: 请求体字典
    func buildRequestBody(
        messages: [ChatMessage],
        model: String,
        tools: [AgentTool]?,
        systemPrompt: String
    ) throws -> [String: Any] {
        // 提取系统消息
        let systemMessage = messages.first(where: { $0.role == .system })?.content ?? systemPrompt

        // 转换对话消息（只发送 user/assistant 给 LLM）
        let conversationMessages = messages
            .filter { $0.role.shouldSendToLLM }
            .map { transformMessage($0) }

        var body: [String: Any] = [
            "model": model,
            "max_tokens": 8192,
            "system": systemMessage,
            "messages": conversationMessages,
        ]

        // 添加工具定义
        if let tools = tools, !tools.isEmpty {
            body["tools"] = tools.map { formatTool($0) }
        }

        return body
    }
    
    // MARK: - Message Transformation
    
    /// 转换消息格式
    ///
    /// 将 ChatMessage 转换为 Anthropic API 所需的格式。
    /// 处理以下特殊情况：
    /// - 工具结果: 转换为 tool_result 类型
    /// - 工具调用: 转换为 tool_use 类型
    /// - 图片附件: 转换为 image source 类型
    /// - 传统图片格式: 支持向后兼容的 marker 格式
    ///
    /// - Parameter message: 原始消息
    /// - Returns: Anthropic API 格式的字典
    func transformMessage(_ message: ChatMessage) -> [String: Any] {
        // 处理工具结果（Tool Result）
        // 当工具执行完成后，结果以 tool_result 类型发送
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

        // 处理工具调用（Tool Use）
        // AI 请求执行工具时生成
        if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
            var content: [[String: Any]] = []

            // 添加文本内容（如果有）
            if !message.content.isEmpty {
                content.append([
                    "type": "text",
                    "text": message.content,
                ])
            }

            // 转换每个工具调用
            for tc in toolCalls {
                // 确保 input 是一个有效的字典
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

        // 处理图片附件
        // Claude 支持图片输入，使用 base64 编码
        if !message.images.isEmpty {
            if Self.verbose {
                Self.logger.info("\(self.t) 消息包含 \(message.images.count) 张图片，正在转换...")
            }

            var content: [[String: Any]] = []

            // 添加文本内容（如果有）
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

        // 处理传统 marker 格式（向后兼容）
        // 格式: [IMAGE_BASE64:<mime_type>:<data>]
        if message.content.contains("[IMAGE_BASE64:") {
            var content: [[String: Any]] = []
            let components = message.content.components(separatedBy: "[IMAGE_BASE64:")

            // 第一个组件是文本内容
            if !components[0].isEmpty {
                content.append([
                    "type": "text",
                    "text": components[0]
                ])
            }

            // 处理每个图片
            for component in components.dropFirst() {
                // 格式: <mime_type>:<data>]<rest_of_text>
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

                    // 添加图片后的文本
                    if !textPart.isEmpty {
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

        // 默认：纯文本消息
        return [
            "role": message.role.rawValue,
            "content": message.content,
        ]
    }

    /// 解析 API 响应
    ///
    /// 从 Anthropic API 响应中提取：
    /// - 文本内容 (type: "text")
    /// - 工具调用 (type: "tool_use")
    ///
    /// - Parameter data: 响应数据
    /// - Returns: (文本内容, 工具调用列表)
    /// - Throws: 解析错误
    func parseResponse(data: Data) throws -> (content: String, toolCalls: [ToolCall]?) {
        // Anthropic 响应结构
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
                    // 处理动态类型的 input 字段
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

        // 遍历响应内容，提取文本和工具调用
        for item in result.content {
            if item.type == "text", let text = item.text {
                textContent += text
            } else if item.type == "tool_use",
                      let id = item.id,
                      let name = item.name,
                      let inputDict = item.input {
                // 将输入字典转换为 JSON 字符串
                let normalDict = inputDict.mapValues { $0.value }
                let inputData = try JSONSerialization.data(withJSONObject: normalDict)
                let inputString = String(data: inputData, encoding: .utf8) ?? "{}"
                toolCalls.append(ToolCall(id: id, name: name, arguments: inputString))
            }
        }

        return (textContent, toolCalls.isEmpty ? nil : toolCalls)
    }

    /// 构建流式请求体
    ///
    /// 在普通请求体基础上添加 stream: true 参数
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
    /// Anthropic SSE 格式示例：
    /// event: content_block_delta
    /// data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}
    ///
    /// event: content_block_stop
    /// data: {"type":"content_block_stop","index":0}
    ///
    /// event: message_stop
    /// data: {"type":"message_stop"}
    func parseStreamChunk(data: Data) throws -> StreamChunk? {
        guard let text = String(data: data, encoding: .utf8) else {
            return nil
        }

        // 解析 SSE 格式（SSE 规范允许多行 data:，需拼接后解析）
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

        let data = eventDataLines.isEmpty ? nil : eventDataLines.joined(separator: "\n")
        guard let data = data, !data.isEmpty else {
            return nil
        }

        // 解析 JSON 数据
        guard let jsonData = data.data(using: .utf8) else {
            return nil
        }

        do {
            let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            let jsonType = json?["type"] as? String
            let effectiveEventType = eventType ?? jsonType ?? "unknown"
            
            // 将字符串事件类型转换为枚举
            let streamEventType = StreamEventType(rawValue: effectiveEventType) ?? .unknown

            // 处理错误
            if let error = json?["error"] as? [String: Any],
               let errorMessage = error["message"] as? String {
                return StreamChunk(
                    error: errorMessage,
                    eventType: .unknown,
                    rawEvent: text
                )
            }

            // 处理 ping 事件 - 不添加内容，只标记事件类型
            if effectiveEventType == "ping" {
                return StreamChunk(
                    eventType: .ping,
                    rawEvent: text
                )
            }

            // 处理消息开始 - 提取 usage 信息
            if effectiveEventType == "message_start" {
                var inputTokens: Int?
                if let message = json?["message"] as? [String: Any],
                   let usage = message["usage"] as? [String: Any] {
                    inputTokens = usage["input_tokens"] as? Int
                }
                return StreamChunk(
                    eventType: .messageStart,
                    rawEvent: text,
                    inputTokens: inputTokens
                )
            }

            // 处理消息增量（包含 stop_reason 和 usage）
            // usage 在 message_delta 中同时包含 input_tokens 和 output_tokens（message_start 可能无 usage 或结构不同，此处作为可靠来源）
            if effectiveEventType == "message_delta" {
                let stopReason = (json?["delta"] as? [String: Any])?["stop_reason"] as? String ?? json?["stop_reason"] as? String
                var inputTokens: Int?
                var outputTokens: Int?
                if let usage = json?["usage"] as? [String: Any] {
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
                return StreamChunk(
                    isDone: true,
                    eventType: .messageStop,
                    rawEvent: text
                )
            }

            // 处理内容块开始
            if effectiveEventType == "content_block_start" {
                if let contentBlock = json?["content_block"] as? [String: Any],
                   let blockType = contentBlock["type"] as? String {

                    // 优先处理思考块 - 不添加内容，只标记事件类型
                    // 必须在 text 块之前处理，因为某些 API 可能在 thinking 块中包含 text 字段
                    if blockType == "thinking" {
                        return StreamChunk(
                            eventType: .contentBlockStart,
                            rawEvent: text
                        )
                    }

                    // 处理工具调用 - 不添加内容到消息，只标记事件
                    if blockType == "tool_use" {
                        if let id = contentBlock["id"] as? String,
                           let name = contentBlock["name"] as? String {
                            let toolCall = ToolCall(
                                id: id,
                                name: name,
                                arguments: "{}"
                            )
                            return StreamChunk(
                                toolCalls: [toolCall],
                                eventType: .contentBlockStart,
                                rawEvent: text
                            )
                        }
                    }

                    // 处理文本块 - 只返回实际文本内容
                    if blockType == "text" {
                        if let textContent = contentBlock["text"] as? String, !textContent.isEmpty {
                            return StreamChunk(
                                content: textContent,
                                eventType: .contentBlockStart,
                                rawEvent: text
                            )
                        }
                        // 空文本块不添加内容
                        return StreamChunk(
                            eventType: .contentBlockStart,
                            rawEvent: text
                        )
                    }

                    // 其他类型内容块不添加内容
                    return StreamChunk(
                        eventType: .contentBlockStart,
                        rawEvent: text
                    )
                }
                // 无法解析的内容块不添加内容
                return StreamChunk(
                    eventType: .contentBlockStart,
                    rawEvent: text
                )
            }

            // 处理内容块增量
            if effectiveEventType == "content_block_delta" {
                if let delta = json?["delta"] as? [String: Any] {
                    let deltaType = delta["type"] as? String

                    // 优先处理 thinking_delta 类型 - 必须在 text 之前检查
                    // 注意：字段名可能是 "thinking" 而不是 "thinking_delta"
                    if let thinkingDelta = delta["thinking_delta"] as? String {
                        return StreamChunk(
                            content: thinkingDelta,
                            eventType: .thinkingDelta,
                            rawEvent: text
                        )
                    }
                    if let thinkingDelta = delta["thinking"] as? String {
                        return StreamChunk(
                            content: thinkingDelta,
                            eventType: .thinkingDelta,
                            rawEvent: text
                        )
                    }

                    // 处理标准 text 字段
                    if let textContent = delta["text"] as? String {
                        return StreamChunk(
                            content: textContent,
                            eventType: .textDelta,
                            rawEvent: text
                        )
                    }

                    // 处理 text_delta 类型
                    if let textDelta = delta["text_delta"] as? String {
                        return StreamChunk(
                            content: textDelta,
                            eventType: .textDelta,
                            rawEvent: text
                        )
                    }
                    
                    // 处理 input_json_delta 类型（工具调用参数）
                    if let partialJson = delta["partial_json"] as? String {
                        return StreamChunk(
                            partialJson: partialJson,
                            eventType: .inputJsonDelta,
                            rawEvent: text
                        )
                    }
                    
                    // 处理 signature_delta 类型 - 不添加内容到消息
                    if delta["signature"] != nil {
                        return StreamChunk(
                            eventType: .signatureDelta,
                            rawEvent: text
                        )
                    }
                    
                    // 未知类型的内容块增量不添加内容
                    return StreamChunk(
                        eventType: .contentBlockDelta,
                        rawEvent: text
                    )
                }
                // 无法解析的内容块增量不添加内容
                return StreamChunk(
                    eventType: .contentBlockDelta,
                    rawEvent: text
                )
            }

            // 处理内容块停止 - 不添加内容到消息
            if effectiveEventType == "content_block_stop" {
                return StreamChunk(
                    eventType: .contentBlockStop,
                    rawEvent: text
                )
            }

            // 处理未知事件类型 - 不添加内容到消息
            return StreamChunk(
                eventType: .unknown,
                rawEvent: text
            )
        } catch {
            if Self.verbose {
                Self.logger.warning("解析流式数据块失败: \(error.localizedDescription)")
            }
            return StreamChunk(
                error: "解析失败: \(error.localizedDescription)",
                eventType: .unknown,
                rawEvent: text
            )
        }
    }

    /// 日志 emoji
    static var logEmoji: String { "🟣" }
}

// MARK: - Tool Formatting

extension AnthropicProvider {
    /// 格式化工具定义
    ///
    /// 将 AgentTool 转换为 Anthropic API 所需的工具格式。
    ///
    /// - Parameter tool: 工具实例
    /// - Returns: Anthropic API 格式的工具定义
    func formatTool(_ tool: AgentTool) -> [String: Any] {
        [
            "name": tool.name,
            "description": tool.description,
            "input_schema": tool.inputSchema,
        ]
    }
}

// MARK: - Helper Types

/// 任意类型解码器
///
/// 用于处理 API 响应中类型不确定的字段。
/// Anthropic 的 tool_use.input 字段类型可能是任意 JSON 类型。
struct AnySendable: Decodable {
    /// 存储的任意类型值
    let value: Any

    /// 从 Decoder 解码
    ///
    /// 尝试依次解码为：Int → Double → String → Bool → Array → Object
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // 尝试按优先级解码为具体类型
        if let x = try? container.decode(Int.self) { value = x }
        else if let x = try? container.decode(Double.self) { value = x }
        else if let x = try? container.decode(String.self) { value = x }
        else if let x = try? container.decode(Bool.self) { value = x }
        else if let x = try? container.decode([String: AnySendable].self) { value = x.mapValues { $0.value } }
        else if let x = try? container.decode([AnySendable].self) { value = x.map { $0.value } }
        else { value = "" }  // 默认空字符串
    }

    /// 直接初始化
    init(value: Any) {
        self.value = value
    }
}

