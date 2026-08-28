import Foundation
import SwiftData

/// 工具调用记录的 SwiftData 持久化模型。
///
/// 与旧内核 `ToolManagerPlugin` 的 `ToolCallRecordModel` 结构一致，
/// 存储目录由宿主通过 `StorageProviding.pluginDataDirectory(for:)` 提供。
@Model
final class ToolCallRecordModel {
    var id: String
    var toolCallID: String?
    var toolName: String
    var toolDisplayName: String
    var turnID: String?
    var conversationID: String
    var createdAt: Date
    var startedAt: Date
    var completedAt: Date?
    var duration: Double?
    var argumentsJSON: String
    var resultContent: String
    var resultJSON: String?
    var resultIsError: Bool
    var riskLevel: String

    init(
        id: String,
        toolCallID: String?,
        toolName: String,
        toolDisplayName: String,
        turnID: String?,
        conversationID: String,
        createdAt: Date,
        startedAt: Date,
        completedAt: Date?,
        duration: Double?,
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
