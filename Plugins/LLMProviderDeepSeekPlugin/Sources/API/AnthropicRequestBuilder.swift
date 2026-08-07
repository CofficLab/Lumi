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
/// - `thinking` 始终启用，`budget_tokens` 由 `reasoningEffort` 控制
enum AnthropicRequestBuilder {
    /// Anthropic Messages API 必填 `max_tokens` 的默认预算。
    /// 用户未在请求中提供时使用；过大不必要，过小会被服务端拒绝。
    static let defaultMaxTokens = 4096

    /// `reasoningEffort` 为 nil 时使用的思考预算。
    ///
    /// 实测(2026-08-06)：DeepSeek V4 服务端**默认开启 thinking 且无预算上限**；
    /// 若请求不显式传 `thinking` 参数，4096 token 输出预算会被思考全部消耗，
    /// 导致 `stop_reason = max_tokens` 且 text 块从未开始(UI 误报 empty response)。
    /// 因此默认档也显式给出保守预算，保证至少留出 text 空间。
    static let defaultThinkingBudget = 1024

    /// 思考预算上限 = max_tokens 预留 text 空间后的余量。
    /// Anthropic 协议要求 `budget_tokens` 严格小于 `max_tokens`。
    static let maxThinkingBudget = defaultMaxTokens - 1024

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

        body["messages"] = buildConversation(conversation)

        if !request.tools.isEmpty {
            body["tools"] = request.tools.map(tool)
        }

        // 始终显式给出 thinking 预算(含 nil),防止服务端默认
        // thinking 无上限吃掉全部输出预算。clamp 到 maxThinkingBudget,
        // 避免 xhigh/max 超过 max_tokens(4096)。
        let requested = thinkingBudget(for: request.generationOptions.reasoningEffort)
            ?? defaultThinkingBudget
        body["thinking"] = [
            "type": "enabled",
            "budget_tokens": min(requested, maxThinkingBudget),
        ]

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

    /// 把对话消息序列化为 Anthropic `messages[]` 数组。
    ///
    /// 关键约束（Anthropic 协议，DeepSeek 严格校验）：一个 assistant 消息里的
    /// 所有 `tool_use` block 必须由**紧随其后的单条** user 消息中的 `tool_result`
    /// block 全部覆盖，不能拆成多条 user 消息。Lumi 的每条 `role == .tool` 消息
    /// 独立存在，这里把**连续的** tool 消息合并为一条 user 消息（内含多个
    /// `tool_result` blocks），在遇到非 tool 消息或流结束时 flush。
    private static func buildConversation(_ messages: [LumiChatMessage]) -> [[String: Any]] {
        var result: [[String: Any]] = []
        var pendingToolResults: [[String: Any]] = []

        for message in messages {
            if message.role == .tool {
                if let toolCallID = message.toolCallID {
                    pendingToolResults.append([
                        "type": "tool_result",
                        "tool_use_id": toolCallID,
                        "content": message.content,
                    ])
                }
                continue
            }
            // 遇到非 tool 消息,先把累积的 tool_result 作为一条 user 消息输出
            if !pendingToolResults.isEmpty {
                result.append(["role": "user", "content": pendingToolResults])
                pendingToolResults = []
            }
            if let mapped = Self.message(message) {
                result.append(mapped)
            }
        }
        if !pendingToolResults.isEmpty {
            result.append(["role": "user", "content": pendingToolResults])
        }
        return result
    }

    /// 把单条 `LumiChatMessage` 映射为 Anthropic `messages[]` 元素。
    ///
    /// - `role=user`：直接生成 `content`（纯文本）
    /// - `role=assistant`：可能同时含 `text` blocks 和 `tool_use` blocks
    /// - `role=tool`：不单独输出——由 `buildConversation` 合并为紧邻的
    ///   user 消息中的 `tool_result` blocks（Anthropic 没有独立 tool 角色）
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
            // 回传 reasoning:DeepSeek V4 默认 thinking 模式,第一轮请求「输出结束位置」
            // 落盘的缓存前缀单元包含 thinking 内容;若回传 assistant 消息时不带 thinking
            // blocks,后续请求的 token 序列与该单元失配,缓存无法命中。
            // Anthropic 协议用 type=thinking block 承载思考内容。
            // ⚠️ signature 必须用响应中 signature_delta 返回的真实值(存于
            // metadata["thinkingSignature"]);用空串或缺失会导致 thinking block 与
            // 缓存落盘单元不一致,从该消息起前缀失配、缓存近乎全 miss(实测 2026-08-06)。
            if let reasoning = message.reasoningContent, !reasoning.isEmpty {
                blocks.append([
                    "type": "thinking",
                    "thinking": reasoning,
                    "signature": message.metadata["thinkingSignature"] ?? "",
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
                        // 历史消息回传同样要转义,否则第二轮请求仍会被 400 拒绝
                        "name": sanitizeToolName(call.name),
                        "input": parseJSONObject(call.arguments),
                    ])
                }
            }
            if blocks.isEmpty { return nil }
            return ["role": "assistant", "content": blocks]
        case .tool:
            // 由 buildConversation 合并处理,此处不应单独到达
            return nil
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
    ///
    /// 工具名经 `sanitizeToolName` 转义:DeepSeek 的 Anthropic 兼容端点严格校验
    /// `tools[].name` 必须匹配 `^[a-zA-Z0-9_-]+$`,而插件工具 id 可能是
    /// `app-store-connect.list-apps` 这类带点号的格式,直接发送会被 400 拒绝。
    private static func tool(_ tool: any LumiAgentTool) -> [String: Any] {
        var value: [String: Any] = [
            "name": sanitizeToolName(tool.name),
            "input_schema": tool.inputSchema.anyValue,
        ]
        if !tool.toolDescription.isEmpty {
            value["description"] = tool.toolDescription
        }
        return value
    }

    /// 返回「sanitize 后名字 → 原始注册名」的映射,供流式响应解析时把模型返回的
    /// 工具名还原为 Lumi 注册 id(工具执行按原始 id 查找)。
    ///
    /// 多个原始名映射到同一 sanitize 名时先注册者优先,保证反查确定性。
    static func toolNameMap(for request: LumiLLMRequest) -> [String: String] {
        var map: [String: String] = [:]
        for tool in request.tools {
            let sanitized = sanitizeToolName(tool.name)
            if map[sanitized] == nil {
                map[sanitized] = tool.name
            }
        }
        return map
    }

    /// 把工具名转义为 DeepSeek Anthropic 端点允许的字符集 `^[a-zA-Z0-9_-]+$`。
    ///
    /// 采用 **ASCII 字节级** 校验(不能用 `Character.isLetter`,它会把中文等
    /// Unicode 字母也判为合法,而服务端模式是纯 ASCII);非法字节统一替换为 `_`。
    static func sanitizeToolName(_ raw: String) -> String {
        var result = ""
        result.reserveCapacity(raw.utf8.count)
        for byte in raw.utf8 {
            let isLegal =
                (byte >= 0x61 && byte <= 0x7A) || // a-z
                (byte >= 0x41 && byte <= 0x5A) || // A-Z
                (byte >= 0x30 && byte <= 0x39) || // 0-9
                byte == 0x5F ||                   // _
                byte == 0x2D                      // -
            result.append(Character(UnicodeScalar(isLegal ? byte : 0x5F)))
        }
        // 空名 / 全非法字符的兜底
        return result.isEmpty ? "tool" : result
    }

    /// 把 `LumiReasoningEffort` 翻译为 Anthropic `thinking.budget_tokens`。
    ///
    /// Anthropic 的 `thinking` 是显式 budget 控制；`nil` 返回 `nil`，
    /// 由调用方回退到 `defaultThinkingBudget`（绝不能"不传 thinking"，否则 DeepSeek
    /// V4 服务端默认 thinking 无上限，会吃掉全部输出预算——实测 2026-08-06）。
    /// 其余档位按经验映射到 token 预算。
    private static func thinkingBudget(for effort: LumiReasoningEffort?) -> Int? {
        switch effort {
        case nil: nil
        case .low: 2048
        case .high: 4096
        case .xhigh: 8192
        case .max: 16384
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
