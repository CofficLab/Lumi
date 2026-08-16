import Foundation

public enum MessageRole: String, Codable, Sendable, CaseIterable {
    case system
    case user
    case assistant
    case tool
    case error
    case status
}

public struct Message: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let conversationID: UUID
    public let role: MessageRole
    public var content: String
    public let createdAt: Date
    public var turnID: UUID?
    public var metadata: [String: String]
    public var isError: Bool

    // MARK: - Rendering metadata
    //
    // 复刻自旧版内核 KernelLumi 的 `LumiChatMessage` 渲染字段，供消息渲染器
    // （PluginMessageRenderer）读取；全部为可选字段，合成 Codable 对缺失键
    // 自动 decodeIfPresent，历史消息无需迁移即可解码。

    /// LLM 供应商 ID（如 "openai"）。
    public var providerID: String?
    /// 模型名称（如 "gpt-4"）。
    public var modelName: String?
    /// 原始错误详情（未格式化的底层错误文本）。
    public var rawErrorDetail: String?
    /// HTTP 错误状态码。
    public var httpStatusCode: Int?
    /// HTTP 响应体文本。
    public var httpBody: String?
    /// 特殊渲染类型（"turn-completed" / "tool-step-group" / "turn-activity" 等）。
    public var renderKind: String?
    /// 期望的渲染器 ID（由消息生产者设置，用于显式路由）。
    public var preferredRendererID: String?
    /// 关联的工具调用 ID。
    public var toolCallID: String?
    /// 思考/推理内容（reasoning）。
    public var reasoningContent: String?
    /// 结构化工具调用列表。
    public var toolCalls: [MessageToolCall]?
    /// 输入 token 数。
    public var inputTokenCount: Int?
    /// 输出 token 数。
    public var outputTokenCount: Int?
    /// 端到端延迟（毫秒）。
    public var latencyMs: Double?
    /// 首 token 时间（毫秒）。
    public var timeToFirstTokenMs: Double?
    /// 流式总时长（毫秒）。
    public var streamingDurationMs: Double?

    public init(
        id: UUID = UUID(),
        conversationID: UUID,
        role: MessageRole,
        content: String,
        createdAt: Date = Date(),
        turnID: UUID? = nil,
        metadata: [String: String] = [:],
        isError: Bool = false,
        providerID: String? = nil,
        modelName: String? = nil,
        rawErrorDetail: String? = nil,
        httpStatusCode: Int? = nil,
        httpBody: String? = nil,
        renderKind: String? = nil,
        preferredRendererID: String? = nil,
        toolCallID: String? = nil,
        reasoningContent: String? = nil,
        toolCalls: [MessageToolCall]? = nil,
        inputTokenCount: Int? = nil,
        outputTokenCount: Int? = nil,
        latencyMs: Double? = nil,
        timeToFirstTokenMs: Double? = nil,
        streamingDurationMs: Double? = nil
    ) {
        self.id = id
        self.conversationID = conversationID
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.turnID = turnID
        self.metadata = metadata
        self.isError = isError
        self.providerID = providerID
        self.modelName = modelName
        self.rawErrorDetail = rawErrorDetail
        self.httpStatusCode = httpStatusCode
        self.httpBody = httpBody
        self.renderKind = renderKind
        self.preferredRendererID = preferredRendererID
        self.toolCallID = toolCallID
        self.reasoningContent = reasoningContent
        self.toolCalls = toolCalls
        self.inputTokenCount = inputTokenCount
        self.outputTokenCount = outputTokenCount
        self.latencyMs = latencyMs
        self.timeToFirstTokenMs = timeToFirstTokenMs
        self.streamingDurationMs = streamingDurationMs
    }
}

// MARK: - Tool Calls
//
// 复刻自旧版内核 KernelLumi 的 `LumiToolCall` / `LumiToolResult`（渲染层所需
// 字段）；去掉 `AgentTurnControl` 依赖，保持 Provider 层自包含。

/// 一次工具调用的展示快照。
public struct MessageToolCall: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let arguments: String
    public var result: MessageToolResult?
    /// 面向用户的操作描述，由对应的 Agent 工具根据参数生成。
    /// 这是持久化的展示快照，UI 不应直接展示 `name`。
    public var displayDescription: String?
    /// 授权状态（`AgentToolKit.ToolCallAuthorizationState` 的 rawValue 字符串）：
    /// `noRisk` / `autoApproved` / `userApproved` / `userRejected` / `pendingAuthorization`。
    /// 缺失视为 `pendingAuthorization`（旧数据兼容）。
    public var authorizationState: String?

    public init(
        id: String,
        name: String,
        arguments: String,
        result: MessageToolResult? = nil,
        displayDescription: String? = nil,
        authorizationState: String? = nil
    ) {
        self.id = id
        self.name = name
        self.arguments = arguments
        self.result = result
        self.displayDescription = displayDescription
        self.authorizationState = authorizationState
    }
}

/// 一次工具调用的结果。
public struct MessageToolResult: Codable, Equatable, Sendable {
    public let content: String
    public let duration: TimeInterval?
    public let isError: Bool
    public let imageAttachments: [MessageImageAttachment]
    /// 工具正在等待用户回答，Agent 循环应暂停（对齐 `ToolCallResult.awaitingUserResponse`）。
    /// 缺失视为 `false`（旧数据兼容）。
    public let awaitingUserResponse: Bool

    public init(
        content: String,
        duration: TimeInterval? = nil,
        isError: Bool = false,
        imageAttachments: [MessageImageAttachment] = [],
        awaitingUserResponse: Bool = false
    ) {
        self.content = content
        self.duration = duration
        self.isError = isError
        self.imageAttachments = imageAttachments
        self.awaitingUserResponse = awaitingUserResponse
    }

    // MARK: Codable（兼容旧数据：awaitingUserResponse 缺失视为 false）

    private enum CodingKeys: String, CodingKey {
        case content, duration, isError, imageAttachments, awaitingUserResponse
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        content = try c.decode(String.self, forKey: .content)
        duration = try c.decodeIfPresent(TimeInterval.self, forKey: .duration)
        isError = try c.decodeIfPresent(Bool.self, forKey: .isError) ?? false
        imageAttachments = try c.decodeIfPresent([MessageImageAttachment].self, forKey: .imageAttachments) ?? []
        awaitingUserResponse = try c.decodeIfPresent(Bool.self, forKey: .awaitingUserResponse) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(content, forKey: .content)
        if let duration { try c.encode(duration, forKey: .duration) }
        if isError { try c.encode(isError, forKey: .isError) }
        if !imageAttachments.isEmpty { try c.encode(imageAttachments, forKey: .imageAttachments) }
        if awaitingUserResponse { try c.encode(awaitingUserResponse, forKey: .awaitingUserResponse) }
    }
}

/// 工具结果附带的图片附件（base64 数据）。
public struct MessageImageAttachment: Codable, Equatable, Sendable {
    public let data: String
    public let mimeType: String

    public init(data: String, mimeType: String = "image/png") {
        self.data = data
        self.mimeType = mimeType
    }
}
