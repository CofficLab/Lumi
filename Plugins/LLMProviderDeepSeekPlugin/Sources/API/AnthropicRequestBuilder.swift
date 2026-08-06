import Foundation
import LumiKernel

/// 把 `LumiLLMRequest` 编码为 Anthropic Messages API 请求体。
///
/// 平行于 `DeepSeekRequestBuilder`。DeepSeek 走 Anthropic 端点
/// (`/v1/messages`) 时使用此 builder 生成的 JSON 由 `DeepSeekAnthropicService` 发送。
///
/// 关键差异（相对于 OpenAI 协议 builder）：
/// - `system` 独立字段（从 `role == .system` 的消息聚合），不在 `messages[]` 中
/// - `tool` 角色的消息序列化为 user message 的 `tool_result` block
/// - `assistant` 消息的 `toolCalls` 序列化为 content 数组里的 `tool_use` blocks，
///   与同一消息的文本 content 共存
/// - `tools[]` 是 `{name, description, input_schema}`，没有 OpenAI 的 `type:function` 包装
/// - `max_tokens` 为 Anthropic 必填项；未指定时取保守默认值
/// - `thinking` 在 `reasoningEffort != nil && != .automatic` 时启用
enum AnthropicRequestBuilder {
    /// Anthropic Messages API 必填 `max_tokens` 的默认预算。
    /// 用户未在请求中提供时使用；过大不必要，过小会被服务端拒绝。
    static let defaultMaxTokens = 4096

    /// 把整个 `LumiLLMRequest` 编码为 `[String: Any]` 请求体。
    static func body(for request: LumiLLMRequest) -> [String: Any] {
        var body: [String: Any] = [
            "model": request.model,
            "max_tokens": defaultMaxTokens,
            "stream": true,
        ]

        let (systemMessages, conversation) = partition(request.messages)
        if !systemMessages.isEmpty {
            body["system"] = mergeSystem(systemMessages)
        }

        body["messages"] = conversation.compactMap { message($0) }

        if !request.tools.isEmpty {
            body["tools"] = request.tools.map(tool)
        }

        if let effort = request.generationOptions.reasoningEffort,
           let budget = thinkingBudget(for: effort)
        {
            body["thinking"] = [
                "type": "enabled",
                "budget_tokens": budget,
            ]
        }

        return body
    }

    // MARK: - 私有

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
        // Anthropic system 字段既支持字符串也支持文本 block 数组；
        // 多条 system 时用数组保留分段语义。
        if texts.count <= 1, let only = texts.first {
            return only
        }
        return texts.map { [ "type": "text", "text": $0 ] }
    }

    /// 把单条 `LumiChatMessage` 映射为 Anthropic `messages[]` 元素。
    ///
    /// - `role=user`：直接生成 `content`（纯文本）
    /// - `role=assistant`：可能同时含 `text` blocks 和 `tool_use` blocks
    /// - `role=tool`：序列化为 user message 的 `tool_result` block（Anthropic 没有独立 tool 角色）
    private static func message(_ message: LumiChatMessage) -> [String: Any]? {
        switch message.role {
        case .system, .error, .status:
            return nil
        case .user:
            return [
                "role": "user",
                "content": textContentBlocks(for: message.content),
            ]
        case .assistant:
            var blocks: [[String: Any]] = []
            if !message.content.isEmpty {
                blocks.append(contentsOf: textContentBlocks(for: message.content))
            }
            if let calls = message.toolCalls {
                for call in calls {
                    blocks.append([
                        "type": "tool_use",
                        "id": call.id,
                        "name": call.name,
                        "input": parseJSONObject(call.arguments),
                    ])
                }
            }
            if blocks.isEmpty { return nil }
            return ["role": "assistant", "content": blocks]
        case .tool:
            guard let toolCallID = message.toolCallID else { return nil }
            // tool 响应以 user message 的 tool_result block 形式出现
            return [
                "role": "user",
                "content": [[
                    "type": "tool_result",
                    "tool_use_id": toolCallID,
                    "content": message.content,
                ]],
            ]
        }
    }

    /// 把字符串转成 Anthropic 的文本 content blocks。
    ///
    /// Anthropic 允许 `content` 直接传字符串；为了和 block 数组场景统一，
    /// 这里统一返回 block 数组形式。
    private static func textContentBlocks(for text: String) -> [[String: Any]] {
        guard !text.isEmpty else { return [] }
        return [["type": "text", "text": text]]
    }

    /// 把 `LumiAgentTool` 映射为 Anthropic `tools[]` 元素。
    private static func tool(_ tool: any LumiAgentTool) -> [String: Any] {
        var value: [String: Any] = [
            "name": tool.name,
            "input_schema": tool.inputSchema.anyValue,
        ]
        if !tool.toolDescription.isEmpty {
            value["description"] = tool.toolDescription
        }
        return value
    }

    /// 把 `LumiReasoningEffort` 翻译为 Anthropic `thinking.budget_tokens`。
    ///
    /// Anthropic 的 `thinking` 是显式 budget 控制；不存在 `.automatic` 这种"让模型决定"的语义，
    /// 因此 `.automatic` 返回 `nil`（不启用 thinking），其余档位按经验映射到 token 预算。
    private static func thinkingBudget(for effort: LumiReasoningEffort) -> Int? {
        switch effort {
        case .automatic: nil
        case .minimal: 1024
        case .low: 2048
        case .medium: 4096
        case .high: 8192
        }
    }

    /// 把工具入参的 JSON 字符串解码为 `[String: Any]`；失败时退化为空对象。
    ///
    /// Anthropic 期望 `input` 是 JSON object；这里优先按对象解析，失败则尝试包一层
    /// （兼容 arguments 是裸值的工具）。`nil` / 空字符串 → `[:]`。
    private static func parseJSONObject(_ arguments: String) -> [String: Any] {
        let trimmed = arguments.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return [:] }
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return object
        }
        if let array = try? JSONSerialization.jsonObject(with: data) as? [Any] {
            return ["_": array]
        }
        // 既不是 object 也不是 array，作为原始字符串包一层
        return ["_": trimmed]
    }
}
