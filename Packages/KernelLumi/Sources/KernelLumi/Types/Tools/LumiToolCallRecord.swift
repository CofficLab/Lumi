import Foundation

/// A persisted snapshot of one tool invocation.
public struct LumiToolCallRecord: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let turnID: UUID?
    public let toolName: String
    public let toolDisplayName: String
    public let conversationID: UUID
    public let createdAt: Date
    public let startedAt: Date
    public let completedAt: Date?
    public let duration: TimeInterval?
    public let argumentsJSON: String
    public let resultContent: String
    public let resultIsError: Bool
    public let riskLevel: String
    public let turnControl: String?

    public init(
        id: String,
        turnID: UUID?,
        toolName: String,
        toolDisplayName: String,
        conversationID: UUID,
        createdAt: Date,
        startedAt: Date,
        completedAt: Date?,
        duration: TimeInterval?,
        argumentsJSON: String,
        resultContent: String,
        resultIsError: Bool,
        riskLevel: String,
        turnControl: String?
    ) {
        self.id = id
        self.turnID = turnID
        self.toolName = toolName
        self.toolDisplayName = toolDisplayName
        self.conversationID = conversationID
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.duration = duration
        self.argumentsJSON = argumentsJSON
        self.resultContent = resultContent
        self.resultIsError = resultIsError
        self.riskLevel = riskLevel
        self.turnControl = turnControl
    }
}
