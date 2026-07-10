import Foundation

public struct LumiChatMessage: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let conversationID: UUID
    public let role: LumiChatMessageRole
    public var content: String
    public let createdAt: Date
    public var providerID: String?
    public var modelName: String?
    public var isError: Bool
    public var rawErrorDetail: String?
    public var renderKind: String?
    public var metadata: [String: String]
    public var toolCalls: [LumiToolCall]?
    public var toolCallID: String?
    public var reasoningContent: String?

    public init(
        id: UUID = UUID(),
        conversationID: UUID,
        role: LumiChatMessageRole,
        content: String,
        createdAt: Date = Date(),
        providerID: String? = nil,
        modelName: String? = nil,
        isError: Bool = false,
        rawErrorDetail: String? = nil,
        renderKind: String? = nil,
        metadata: [String: String] = [:],
        toolCalls: [LumiToolCall]? = nil,
        toolCallID: String? = nil,
        reasoningContent: String? = nil
    ) {
        self.id = id
        self.conversationID = conversationID
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.providerID = providerID
        self.modelName = modelName
        self.isError = isError
        self.rawErrorDetail = rawErrorDetail
        self.renderKind = renderKind
        self.metadata = metadata
        self.toolCalls = toolCalls
        self.toolCallID = toolCallID
        self.reasoningContent = reasoningContent
    }
}

public extension LumiChatMessage {
    /// 是否为「空响应」：无可见文本、无工具调用、非错误消息。
    ///
    /// 这类响应对用户完全不可见，通常是模型异常终止（如 Gemini 2.5 Pro 的
    /// 已知空响应 bug、流式中断、或上下文过长导致模型放弃）。
    ///
    /// 判定标准：
    /// - `isError == false`（错误消息走独立的 error 处理路径）
    /// - `content` 去除首尾空白后为空
    /// - `toolCalls` 为 nil 或空数组
    ///
    /// 注意：`reasoningContent`（thinking）不参与判空——即使有 thinking，
    /// 如果正文为空，用户仍然看不到任何回应。
    var isEmptyResponse: Bool {
        guard !isError else { return false }
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedContent.isEmpty else { return false }
        let hasToolCalls = toolCalls?.isEmpty == false
        guard !hasToolCalls else { return false }
        return true
    }
}
