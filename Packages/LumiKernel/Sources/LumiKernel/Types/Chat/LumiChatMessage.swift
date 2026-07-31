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
    public var inputTokenCount: Int?
    public var outputTokenCount: Int?
    public var latencyMs: Double?
    public var timeToFirstTokenMs: Double?
    public var streamingDurationMs: Double?

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
        reasoningContent: String? = nil,
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
        self.providerID = providerID
        self.modelName = modelName
        self.isError = isError
        self.rawErrorDetail = rawErrorDetail
        self.renderKind = renderKind
        self.metadata = metadata
        self.toolCalls = toolCalls
        self.toolCallID = toolCallID
        self.reasoningContent = reasoningContent
        self.inputTokenCount = inputTokenCount
        self.outputTokenCount = outputTokenCount
        self.latencyMs = latencyMs
        self.timeToFirstTokenMs = timeToFirstTokenMs
        self.streamingDurationMs = streamingDurationMs
    }
}

public extension LumiChatMessage {
    /// 是否为「空响应」：无可见文本、无工具调用、非错误消息。
    var isEmptyResponse: Bool {
        guard !isError else { return false }
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedContent.isEmpty else { return false }
        let hasToolCalls = toolCalls?.isEmpty == false
        guard !hasToolCalls else { return false }
        return true
    }

    /// 是否「模型把工具调用写进了正文而非结构化 `toolCalls`」。
    var hasInlineToolCallInBody: Bool {
        guard !isError else { return false }
        let hasStructuredToolCalls = toolCalls?.isEmpty == false
        guard !hasStructuredToolCalls else { return false }
        return InlineToolCallDetector.detected(in: content)
    }
}

/// 检测正文中内嵌的工具调用格式
public enum InlineToolCallDetector {
    public static func detected(in content: String) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.contains("<tool_call>")
            || trimmed.contains("<function_calls>")
            || trimmed.contains("【tool_call】")
    }
}
