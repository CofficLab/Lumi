import Foundation
import LLMKit
import LumiKernel

/// Anthropic Messages API 请求构建器。
enum AliyunAnthropicRequestBuilder {
    static let defaultMaxTokens = 4096
    static let defaultThinkingBudget = 1024
    static let maxThinkingBudget = defaultMaxTokens - 1024

    static func body(for request: LumiLLMRequest) -> [String: Any] {
        var body: [String: Any] = [
            "model": request.model,
            "max_tokens": defaultMaxTokens,
            "stream": true,
        ]

        let mergedMessages = mergeRequestLevelImages(request.messages, imageAttachments: request.imageAttachments)
        let (systemMessages, conversation) = partition(mergedMessages)
        if !systemMessages.isEmpty {
            body["system"] = mergeSystem(systemMessages)
        }

        body["messages"] = buildConversation(conversation)

        if !request.tools.isEmpty {
            body["tools"] = request.tools.map(tool)
        }

        // 思考预算
        let requested = thinkingBudget(for: request.reasoningEffort)
            ?? defaultThinkingBudget
        body["thinking"] = [
            "type": "enabled",
            "budget_tokens": min(requested, maxThinkingBudget),
        ]

        return body
    }

    /// 返回「sanitize 后名字 → 原始注册名」的映射,供流式响应解析时把模型回传的
    /// 工具名还原为 Lumi 注册 id(工具执行按原始 id 查找)。
    ///
    /// 背景:Anthropic 工具名规范要求 `^[a-zA-Z0-9_-]{1,64}$`,不允许点号。而 Lumi 工具
    /// id 普遍采用 `plugin.action` 形式(如 `app-store-connect.list-apps`),`LLMToolNameSanitizer`
    /// 在发给模型时把点号替换成下划线。模型回传的 sanitized 名若不还原,`ToolManagerService`
    /// 会因注册名(带点)与回传名(下划线)不一致而报 "Tool not found"。
    ///
    /// 多个原始名映射到同一 sanitize 名时先注册者优先,保证反查确定性
    /// (与 DeepSeek 插件 `AnthropicRequestBuilder.toolNameMap` 的策略一致)。
    static func toolNameMap(for request: LumiLLMRequest) -> [String: String] {
        var map: [String: String] = [:]
        for tool in request.tools {
            let sanitized = LLMToolNameSanitizer.sanitize(tool.name)
            if map[sanitized] == nil {
                map[sanitized] = tool.name
            }
        }
        return map
    }

    /// 把 `request.imageAttachments`（请求级附件）合并到最后一条 user 消息的 metadata，
    /// 使其与本构建器「只读消息 metadata」的图片链路（`imageContentBlocks(for:)`）兼容。
    ///
    /// 背景：本构建器（以及 `message(_:)` / `toolResultBlock(...)`）构造请求体时只从
    /// `message.metadata["imageAttachments"]` 取图，从不读 `request.imageAttachments`。
    /// 正常 agent turn 路径由 `AgentTurnRunner`/`MessageSender` 把图写进 metadata，故正常；
    /// 但「直接调用」路径（`sendDirect`/`generateText`，如标题生成、插件内置审核）只设
    /// `request.imageAttachments`，消息 metadata 为空，导致这些路径在阿里云 provider 下静默丢图。
    ///
    /// 合并策略：以最后一条 user 消息为目标，按 `id` 去重（metadata 已有的不重复加入），
    /// 再整体编码回 metadata。与通用 `MessageBridge.attachRequestImages` 的「附加到最后一条
    /// user 消息」语义一致。
    private static func mergeRequestLevelImages(
        _ messages: [LumiChatMessage],
        imageAttachments: [LumiImageAttachment]
    ) -> [LumiChatMessage] {
        guard !imageAttachments.isEmpty else { return messages }
        guard let lastIndex = messages.lastIndex(where: { $0.role == .user }) else {
            return messages
        }
        var merged = messages
        let target = merged[lastIndex]
        let existing = LumiImageAttachmentMetadata.decode(from: target.metadata)
        let existingIDs = Set(existing.map(\.id))
        let additions = imageAttachments.filter { !existingIDs.contains($0.id) }
        guard !additions.isEmpty else { return messages }
        let combined = existing + additions
        merged[lastIndex].metadata = LumiImageAttachmentMetadata.encode(combined, into: target.metadata)
        return merged
    }

    private static func partition(_ messages: [LumiChatMessage]) -> (system: [LumiChatMessage], rest: [LumiChatMessage]) {
        var system: [LumiChatMessage] = []
        var rest: [LumiChatMessage] = []
        for message in messages {
            if message.role == .system { system.append(message) }
            else if message.role == .error || message.role == .status { continue }
            else { rest.append(message) }
        }
        return (system, rest)
    }

    private static func mergeSystem(_ messages: [LumiChatMessage]) -> Any {
        let texts = messages.map(\.content).filter { !$0.isEmpty }
        if texts.count <= 1, let only = texts.first {
            return only
        }
        return texts.map { [ "type": "text", "text": $0 ] }
    }

    private static func buildConversation(_ messages: [LumiChatMessage]) -> [[String: Any]] {
        var result: [[String: Any]] = []
        var pendingToolResults: [[String: Any]] = []

        for message in messages {
            if message.role == .tool {
                if let toolCallID = message.toolCallID {
                    pendingToolResults.append(toolResultBlock(
                        toolCallID: toolCallID,
                        text: message.content,
                        images: imageContentBlocks(for: message.metadata)
                    ))
                }
                continue
            }
            if !pendingToolResults.isEmpty {
                result.append(toolResultMessage(results: pendingToolResults))
                pendingToolResults = []
            }
            if let mapped = Self.message(message) {
                result.append(mapped)
            }
        }
        if !pendingToolResults.isEmpty {
            result.append(toolResultMessage(results: pendingToolResults))
        }
        return result
    }

    private static func toolResultBlock(
        toolCallID: String,
        text: String,
        images: [[String: Any]]
    ) -> [String: Any] {
        guard !images.isEmpty else {
            return [
                "type": "tool_result",
                "tool_use_id": toolCallID,
                "content": text,
            ]
        }

        var content = textContentBlocks(for: text) + images
        content.append([
            "type": "text",
            "text": "请结合用户当前请求分析这张工具返回的图片。不要根据文件路径、文件名或目录信息猜测图片内容。",
        ])
        return [
            "type": "tool_result",
            "tool_use_id": toolCallID,
            "content": content,
        ]
    }

    private static func toolResultMessage(results: [[String: Any]]) -> [String: Any] {
        // tool_result 必须是 user content 中最前面的 blocks。图片嵌入各自的
        // tool_result.content，避免兼容层把兄弟 image block 当作无关附件忽略。
        let content = results
        return [
            "role": "user",
            "content": content,
        ]
    }

    private static func message(_ message: LumiChatMessage) -> [String: Any]? {
        switch message.role {
        case .system, .error, .status:
            return nil
        case .user:
            return [
                "role": "user",
                "content": imageContentBlocks(for: message.metadata) + textContentBlocks(for: message.content),
            ]
        case .assistant:
            var blocks: [[String: Any]] = []
            if let reasoning = message.reasoningContent, !reasoning.isEmpty {
                blocks.append([
                    "type": "thinking",
                    "thinking": reasoning,
                ])
            }
            if !message.content.isEmpty {
                blocks.append(contentsOf: textContentBlocks(for: message.content))
            }
            if let calls = message.toolCalls {
                for call in calls {
                    blocks.append([
                        "type": "tool_use",
                        "id": call.id,
                        "name": LLMToolNameSanitizer.sanitize(call.name),
                        "input": call.arguments.isEmpty ? [:] : parseJSONObject(call.arguments),
                    ])
                }
            }
            if blocks.isEmpty { return nil }
            return ["role": "assistant", "content": blocks]
        case .tool:
            return nil
        }
    }

    private static func textContentBlocks(for text: String) -> [[String: Any]] {
        guard !text.isEmpty else { return [] }
        return [["type": "text", "text": text]]
    }

    private static func imageContentBlocks(for metadata: [String: String]) -> [[String: Any]] {
        imageContentBlocks(for: LumiImageAttachmentMetadata.decode(from: metadata))
    }

    private static func imageContentBlocks(for attachments: [LumiImageAttachment]) -> [[String: Any]] {
        attachments.compactMap { attachment in
            guard !attachment.base64Data.isEmpty,
                  attachment.mimeType.hasPrefix("image/")
            else { return nil }

            return [
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": attachment.mimeType,
                    "data": attachment.base64Data,
                ],
            ]
        }
    }

    private static func tool(_ tool: any LumiAgentTool) -> [String: Any] {
        var value: [String: Any] = [
            "name": LLMToolNameSanitizer.sanitize(tool.name),
            "input_schema": tool.inputSchema.anyValue,
        ]
        if !tool.toolDescription.isEmpty {
            value["description"] = tool.toolDescription
        }
        return value
    }

    private static func thinkingBudget(for effort: LumiReasoningEffort?) -> Int? {
        switch effort {
        case nil: nil
        case .low: 2048
        case .medium: 3072
        case .high: 4096
        case .xhigh: 8192
        case .max: 16384
        }
    }

    private static func parseJSONObject(_ json: String) -> [String: Any] {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return object
    }
}
