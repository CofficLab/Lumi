import Foundation

// MARK: - ContentBlock

/// ACP 内容块，与 MCP 的 ContentBlock 结构一致，便于直接转发 MCP 工具输出。
///
/// 出现在：`session/prompt` 的用户提示、`session/update` 的流式输出、工具调用结果。
/// 参考：https://agentclientprotocol.com/protocol/content
public enum ContentBlock: Sendable, Equatable {
    /// 纯文本。
    case text(String, annotations: Annotations? = nil)
    /// Base64 图片（入提示需 `promptCapabilities.image`）。
    case image(mimeType: String, data: String, uri: String?, annotations: Annotations?)
    /// Base64 音频（入提示需 `promptCapabilities.audio`）。
    case audio(mimeType: String, data: String, annotations: Annotations?)
    /// 内嵌完整资源（入提示需 `promptCapabilities.embeddedContext`）。
    case resource(EmbeddedResource, annotations: Annotations?)
    /// 资源链接引用（Agent 可直接访问）。
    case resourceLink(uri: String, name: String, mimeType: String?, title: String?, description: String?, size: Int?, annotations: Annotations?)
}

/// 内容块元数据（可选）。
/// 字段结构与 MCP annotations 对齐；ACP 官方 schema 细节以 https://agentclientprotocol.com/protocol/content 为准。
public struct Annotations: Sendable, Equatable, Codable {
    /// 内容面向的受众（如 "user" / "assistant"）。
    public var audience: [String]?
    /// 内容展示优先级（0.0 ~ 1.0）。
    public var priority: Double?

    public init(audience: [String]? = nil, priority: Double? = nil) {
        self.audience = audience
        self.priority = priority
    }
}

/// 内嵌资源内容：文本或二进制二选一。
public struct EmbeddedResource: Sendable, Equatable, Codable {
    /// 资源 URI。
    public var uri: String
    /// 文本内容（与 blob 互斥）。
    public var text: String?
    /// Base64 二进制内容（与 text 互斥）。
    public var blob: String?
    /// 内容 MIME 类型。
    public var mimeType: String?

    public init(uri: String, text: String? = nil, blob: String? = nil, mimeType: String? = nil) {
        self.uri = uri
        self.text = text
        self.blob = blob
        self.mimeType = mimeType
    }
}

// MARK: - ContentBlock Codable（按 type 判别）

extension ContentBlock: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, text, annotations, mimeType, data, uri, resource, name, title, description, size
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        let annotations = try c.decodeIfPresent(Annotations.self, forKey: .annotations)
        switch type {
        case "text":
            let text = try c.decode(String.self, forKey: .text)
            self = .text(text, annotations: annotations)
        case "image":
            self = .image(
                mimeType: try c.decode(String.self, forKey: .mimeType),
                data: try c.decode(String.self, forKey: .data),
                uri: try c.decodeIfPresent(String.self, forKey: .uri),
                annotations: annotations
            )
        case "audio":
            self = .audio(
                mimeType: try c.decode(String.self, forKey: .mimeType),
                data: try c.decode(String.self, forKey: .data),
                annotations: annotations
            )
        case "resource":
            let resource = try c.decode(EmbeddedResource.self, forKey: .resource)
            self = .resource(resource, annotations: annotations)
        case "resource_link":
            self = .resourceLink(
                uri: try c.decode(String.self, forKey: .uri),
                name: try c.decode(String.self, forKey: .name),
                mimeType: try c.decodeIfPresent(String.self, forKey: .mimeType),
                title: try c.decodeIfPresent(String.self, forKey: .title),
                description: try c.decodeIfPresent(String.self, forKey: .description),
                size: try c.decodeIfPresent(Int.self, forKey: .size),
                annotations: annotations
            )
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: c.codingPath, debugDescription: "未知 ContentBlock type：\(type)"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text, let annotations):
            try c.encode("text", forKey: .type)
            try c.encode(text, forKey: .text)
            try c.encodeIfPresent(annotations, forKey: .annotations)
        case .image(let mimeType, let data, let uri, let annotations):
            try c.encode("image", forKey: .type)
            try c.encode(mimeType, forKey: .mimeType)
            try c.encode(data, forKey: .data)
            try c.encodeIfPresent(uri, forKey: .uri)
            try c.encodeIfPresent(annotations, forKey: .annotations)
        case .audio(let mimeType, let data, let annotations):
            try c.encode("audio", forKey: .type)
            try c.encode(mimeType, forKey: .mimeType)
            try c.encode(data, forKey: .data)
            try c.encodeIfPresent(annotations, forKey: .annotations)
        case .resource(let resource, let annotations):
            try c.encode("resource", forKey: .type)
            try c.encode(resource, forKey: .resource)
            try c.encodeIfPresent(annotations, forKey: .annotations)
        case .resourceLink(let uri, let name, let mimeType, let title, let description, let size, let annotations):
            try c.encode("resource_link", forKey: .type)
            try c.encode(uri, forKey: .uri)
            try c.encode(name, forKey: .name)
            try c.encodeIfPresent(mimeType, forKey: .mimeType)
            try c.encodeIfPresent(title, forKey: .title)
            try c.encodeIfPresent(description, forKey: .description)
            try c.encodeIfPresent(size, forKey: .size)
            try c.encodeIfPresent(annotations, forKey: .annotations)
        }
    }
}

// MARK: - Plan

/// 计划条目。
/// 参考：https://agentclientprotocol.com/protocol/agent-plan
public struct PlanEntry: Sendable, Equatable, Codable {
    /// 任务描述。
    public var content: String
    /// 优先级。
    public var priority: PlanEntryPriority
    /// 执行状态。
    public var status: PlanEntryStatus

    public init(content: String, priority: PlanEntryPriority, status: PlanEntryStatus) {
        self.content = content
        self.priority = priority
        self.status = status
    }
}

public enum PlanEntryPriority: String, Sendable, Equatable, Codable {
    case high, medium, low
}

public enum PlanEntryStatus: String, Sendable, Equatable, Codable {
    case pending
    case inProgress = "in_progress"
    case completed
}

// MARK: - Tool Call

/// 工具调用类型（帮助 Client 选择图标与展示方式）。
/// 参考：https://agentclientprotocol.com/protocol/tool-calls
public enum ToolKind: String, Sendable, Equatable, Codable {
    case read
    case edit
    case delete
    case move
    case search
    case execute
    case think
    case fetch
    case switchMode = "switch_mode"
    case other
}

/// 工具执行状态。
public enum ToolCallStatus: String, Sendable, Equatable, Codable {
    /// 尚未开始：输入流式传输中或等待审批。
    case pending
    case inProgress = "in_progress"
    case completed
    case failed
    case cancelled
}

/// 工具调用产生的展示内容。
public enum ToolCallContent: Sendable, Equatable {
    /// 常规内容块（文本/图片/资源）。
    case content(ContentBlock)
    /// 文件修改的 diff。
    case diff(path: String, oldText: String?, newText: String)
    /// 终端实时输出引用。
    case terminal(terminalId: String)
}

extension ToolCallContent: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, content, path, oldText, newText, terminalId
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "content":
            self = .content(try c.decode(ContentBlock.self, forKey: .content))
        case "diff":
            self = .diff(
                path: try c.decode(String.self, forKey: .path),
                oldText: try c.decodeIfPresent(String.self, forKey: .oldText),
                newText: try c.decode(String.self, forKey: .newText)
            )
        case "terminal":
            self = .terminal(terminalId: try c.decode(String.self, forKey: .terminalId))
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: c.codingPath, debugDescription: "未知 ToolCallContent type：\(type)"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .content(let block):
            try c.encode("content", forKey: .type)
            try c.encode(block, forKey: .content)
        case .diff(let path, let oldText, let newText):
            try c.encode("diff", forKey: .type)
            try c.encode(path, forKey: .path)
            try c.encodeIfPresent(oldText, forKey: .oldText)
            try c.encode(newText, forKey: .newText)
        case .terminal(let terminalId):
            try c.encode("terminal", forKey: .type)
            try c.encode(terminalId, forKey: .terminalId)
        }
    }
}

/// 工具调用影响的文件位置（编辑器"跟随"能力）。
public struct ToolCallLocation: Sendable, Equatable, Codable {
    /// 绝对路径。
    public var path: String
    /// 行号（1-based，可选）。
    public var line: Int?

    public init(path: String, line: Int? = nil) {
        self.path = path
        self.line = line
    }
}

/// 工具调用报告（`tool_call` 与 `tool_call_update` 共用结构）。
///
/// `tool_call_update` 中除 `toolCallId` 外所有字段均可选，仅包含变化字段。
public struct ToolCallUpdate: Sendable, Equatable, Codable {
    /// 会话内唯一工具调用 ID。
    public var toolCallId: String
    /// 人类可读的工具行为描述。
    public var title: String?
    /// 工具类别。
    public var kind: ToolKind?
    /// 执行状态。
    public var status: ToolCallStatus?
    /// 工具产生的展示内容。
    public var content: [ToolCallContent]?
    /// 影响的文件位置。
    public var locations: [ToolCallLocation]?
    /// 传入工具的原始参数。
    public var rawInput: JSONValue?
    /// 工具返回的原始输出。
    public var rawOutput: JSONValue?

    public init(
        toolCallId: String,
        title: String? = nil,
        kind: ToolKind? = nil,
        status: ToolCallStatus? = nil,
        content: [ToolCallContent]? = nil,
        locations: [ToolCallLocation]? = nil,
        rawInput: JSONValue? = nil,
        rawOutput: JSONValue? = nil
    ) {
        self.toolCallId = toolCallId
        self.title = title
        self.kind = kind
        self.status = status
        self.content = content
        self.locations = locations
        self.rawInput = rawInput
        self.rawOutput = rawOutput
    }
}

// MARK: - StopReason

/// 回合停止原因（`session/prompt` 响应）。
/// 参考：https://agentclientprotocol.com/protocol/prompt-turn
public enum StopReason: String, Sendable, Equatable, Codable {
    /// 模型完成响应且未请求更多工具。
    case endTurn = "end_turn"
    /// 达到最大 token 限制。
    case maxTokens = "max_tokens"
    /// 单回合内达到最大模型请求次数。
    case maxTurnRequests = "max_turn_requests"
    /// Agent 拒绝继续。
    case refusal
    /// Client 取消了回合。
    case cancelled
}

// MARK: - SessionUpdate

/// `session/update` 通知的更新载荷（按 `sessionUpdate` 判别字段分发）。
///
/// 已知变体：plan / agent_message_chunk / user_message_chunk / thought_message_chunk /
/// tool_call / tool_call_update / available_commands / current_mode_update。
/// 参考：https://agentclientprotocol.com/protocol/overview、/prompt-turn、/session-modes、/agent-plan
public enum SessionUpdate: Sendable, Equatable {
    /// Agent 的执行计划（每次发送完整列表，Client 整体替换）。
    case plan([PlanEntry])
    /// Agent 消息增量（流式）。
    case agentMessageChunk(ContentBlock)
    /// 用户消息回放（`session/load` 回放历史时使用）。
    case userMessageChunk(ContentBlock)
    /// 思考消息增量。
    case thoughtMessageChunk(ContentBlock)
    /// 报告新的工具调用。
    case toolCall(ToolCallUpdate)
    /// 工具调用状态更新。
    case toolCallUpdate(ToolCallUpdate)
    /// 可用斜杠命令更新。
    /// 注意：SlashCommand 字段以官方 schema 为准，MVP 不依赖。
    case availableCommands([SlashCommand])
    /// Agent 切换了当前模式。
    case currentModeUpdate(modeId: String)
}

/// 斜杠命令描述（`available_commands` 载荷）。
/// 字段以官方 schema 为准（https://agentclientprotocol.com/protocol/slash-commands），MVP 不依赖。
public struct SlashCommand: Sendable, Equatable, Codable {
    public var id: String
    public var title: String
    public var description: String?

    public init(id: String, title: String, description: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
    }
}

extension SessionUpdate: Codable {
    private enum CodingKeys: String, CodingKey {
        case sessionUpdate, entries, content, toolCallId, title, kind, status, locations, rawInput, rawOutput, commands, modeId
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(String.self, forKey: .sessionUpdate)
        switch kind {
        case "plan":
            self = .plan(try c.decode([PlanEntry].self, forKey: .entries))
        case "agent_message_chunk":
            self = .agentMessageChunk(try c.decode(ContentBlock.self, forKey: .content))
        case "user_message_chunk":
            self = .userMessageChunk(try c.decode(ContentBlock.self, forKey: .content))
        case "thought_message_chunk":
            self = .thoughtMessageChunk(try c.decode(ContentBlock.self, forKey: .content))
        case "tool_call":
            self = .toolCall(try Self.decodeToolCallUpdate(from: c))
        case "tool_call_update":
            self = .toolCallUpdate(try Self.decodeToolCallUpdate(from: c))
        case "available_commands":
            self = .availableCommands(try c.decode([SlashCommand].self, forKey: .commands))
        case "current_mode_update":
            self = .currentModeUpdate(modeId: try c.decode(String.self, forKey: .modeId))
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: c.codingPath, debugDescription: "未知 sessionUpdate 类型：\(kind)"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .plan(let entries):
            try c.encode("plan", forKey: .sessionUpdate)
            try c.encode(entries, forKey: .entries)
        case .agentMessageChunk(let block):
            try c.encode("agent_message_chunk", forKey: .sessionUpdate)
            try c.encode(block, forKey: .content)
        case .userMessageChunk(let block):
            try c.encode("user_message_chunk", forKey: .sessionUpdate)
            try c.encode(block, forKey: .content)
        case .thoughtMessageChunk(let block):
            try c.encode("thought_message_chunk", forKey: .sessionUpdate)
            try c.encode(block, forKey: .content)
        case .toolCall(let update):
            try c.encode("tool_call", forKey: .sessionUpdate)
            try Self.encodeToolCallUpdate(update, to: &c)
        case .toolCallUpdate(let update):
            try c.encode("tool_call_update", forKey: .sessionUpdate)
            try Self.encodeToolCallUpdate(update, to: &c)
        case .availableCommands(let commands):
            try c.encode("available_commands", forKey: .sessionUpdate)
            try c.encode(commands, forKey: .commands)
        case .currentModeUpdate(let modeId):
            try c.encode("current_mode_update", forKey: .sessionUpdate)
            try c.encode(modeId, forKey: .modeId)
        }
    }

    private static func decodeToolCallUpdate(from c: KeyedDecodingContainer<CodingKeys>) throws -> ToolCallUpdate {
        ToolCallUpdate(
            toolCallId: try c.decode(String.self, forKey: .toolCallId),
            title: try c.decodeIfPresent(String.self, forKey: .title),
            kind: try c.decodeIfPresent(ToolKind.self, forKey: .kind),
            status: try c.decodeIfPresent(ToolCallStatus.self, forKey: .status),
            content: try c.decodeIfPresent([ToolCallContent].self, forKey: .content),
            locations: try c.decodeIfPresent([ToolCallLocation].self, forKey: .locations),
            rawInput: try c.decodeIfPresent(JSONValue.self, forKey: .rawInput),
            rawOutput: try c.decodeIfPresent(JSONValue.self, forKey: .rawOutput)
        )
    }

    private static func encodeToolCallUpdate(_ update: ToolCallUpdate, to c: inout KeyedEncodingContainer<CodingKeys>) throws {
        try c.encode(update.toolCallId, forKey: .toolCallId)
        try c.encodeIfPresent(update.title, forKey: .title)
        try c.encodeIfPresent(update.kind, forKey: .kind)
        try c.encodeIfPresent(update.status, forKey: .status)
        try c.encodeIfPresent(update.content, forKey: .content)
        try c.encodeIfPresent(update.locations, forKey: .locations)
        try c.encodeIfPresent(update.rawInput, forKey: .rawInput)
        try c.encodeIfPresent(update.rawOutput, forKey: .rawOutput)
    }
}
