import Foundation
import SwiftData

/// 每次工具调用的持久化记录。
///
/// 由 `ToolCallRecordStore` 使用 SwiftData 持久化到
/// `storage.pluginDataDirectory(for: "ToolManager")` 下的 SQLite 文件。
@Model
final class ToolCallRecordModel {
    @Attribute(.unique) var id: String
    /// The original `LumiToolCall.id`. Optional for lightweight migration of
    /// records written before result lookup was introduced.
    var toolCallID: String?
    var toolName: String
    var toolDisplayName: String
    /// Optional for lightweight migration of records created before turn tracking.
    var turnID: String?
    var conversationID: String
    var createdAt: Date
    var startedAt: Date
    var completedAt: Date?
    var duration: Double?
    var argumentsJSON: String
    var resultContent: String
    /// Full Codable result snapshot, when available. Optional for old records.
    var resultJSON: String?
    var resultIsError: Bool
    var riskLevel: String
    var turnControl: String?

    init(
        id: String,
        toolCallID: String? = nil,
        toolName: String,
        toolDisplayName: String,
        turnID: String? = nil,
        conversationID: String,
        createdAt: Date,
        startedAt: Date,
        completedAt: Date? = nil,
        duration: Double? = nil,
        argumentsJSON: String,
        resultContent: String,
        resultJSON: String? = nil,
        resultIsError: Bool,
        riskLevel: String,
        turnControl: String? = nil
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
        self.turnControl = turnControl
    }
}
