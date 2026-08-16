import Foundation

/// 一次工具调用的持久化快照（纯数据副本）。
///
/// 对应旧内核的 `LumiToolCallRecord`。与 SwiftData managed 对象隔离，
/// 便于跨 actor 传递与在 SwiftUI 视图中展示。
public struct ToolCallRecord: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    /// 原始 `ToolCall.id`（可能为空：早期记录或非标准调用）。
    public let toolCallID: String?
    public let toolName: String
    public let toolDisplayName: String
    public let turnID: UUID?
    public let conversationID: UUID
    public let createdAt: Date
    public let startedAt: Date
    public let completedAt: Date?
    public let duration: TimeInterval?
    public let argumentsJSON: String
    public let resultContent: String
    public let resultJSON: String?
    public let resultIsError: Bool
    public let riskLevel: String

    public init(
        id: String,
        toolCallID: String?,
        toolName: String,
        toolDisplayName: String,
        turnID: UUID?,
        conversationID: UUID,
        createdAt: Date,
        startedAt: Date,
        completedAt: Date?,
        duration: TimeInterval?,
        argumentsJSON: String,
        resultContent: String,
        resultJSON: String?,
        resultIsError: Bool,
        riskLevel: String
    ) {
        self.id = id
        self.toolCallID = toolCallID
        self.toolName = toolName
        self.toolDisplayName = toolDisplayName
        self.turnID = turnID
        self.conversationID = conversationID
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.duration = duration
        self.argumentsJSON = argumentsJSON
        self.resultContent = resultContent
        self.resultJSON = resultJSON
        self.resultIsError = resultIsError
        self.riskLevel = riskLevel
    }
}
