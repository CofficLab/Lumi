import Foundation
import KitAgentTool
import SwiftData

/// Tool Job 持久化模型。
///
/// 只保存 SwiftData 支持的基础字段；结构化结果编码为 JSON，跨 actor 返回
/// 时由 `ToolJobRecordStore` 解码成值类型。
@Model
final class ToolJobRecordModel {
    var id: String
    var conversationID: String
    var turnID: String?
    var toolName: String
    var argumentsJSON: String
    var argumentsHash: String
    var status: String
    var createdAt: Date
    var startedAt: Date?
    var updatedAt: Date
    var latestOutput: String
    var outputByteCount: Int
    var processID: Int32?
    var cancelRequested: Bool
    var completedAt: Date?
    var resultJSON: String?
    var errorMessage: String?

    init(record: ToolJobRecord) {
        self.id = record.id
        self.conversationID = record.conversationID.uuidString
        self.turnID = record.turnID?.uuidString
        self.toolName = record.toolName
        self.argumentsJSON = record.argumentsJSON
        self.argumentsHash = record.argumentsHash
        self.status = record.status.rawValue
        self.createdAt = record.createdAt
        self.startedAt = record.startedAt
        self.updatedAt = record.updatedAt
        self.latestOutput = record.latestOutput
        self.outputByteCount = record.outputByteCount
        self.processID = record.processID
        self.cancelRequested = record.cancelRequested
        self.completedAt = record.completedAt
        self.resultJSON = record.result.flatMap { try? Self.encode($0) }
        self.errorMessage = record.errorMessage
    }

    func update(with record: ToolJobRecord) {
        conversationID = record.conversationID.uuidString
        turnID = record.turnID?.uuidString
        toolName = record.toolName
        argumentsJSON = record.argumentsJSON
        argumentsHash = record.argumentsHash
        status = record.status.rawValue
        createdAt = record.createdAt
        startedAt = record.startedAt
        updatedAt = record.updatedAt
        latestOutput = record.latestOutput
        outputByteCount = record.outputByteCount
        processID = record.processID
        cancelRequested = record.cancelRequested
        completedAt = record.completedAt
        resultJSON = record.result.flatMap { try? Self.encode($0) }
        errorMessage = record.errorMessage
    }

    func value() -> ToolJobRecord? {
        guard let conversationID = UUID(uuidString: conversationID),
              let status = ToolJobStatus(rawValue: status) else {
            return nil
        }

        let result = resultJSON.flatMap { Self.decodeResult($0) }
        return ToolJobRecord(
            id: id,
            conversationID: conversationID,
            turnID: turnID.flatMap(UUID.init(uuidString:)),
            toolName: toolName,
            argumentsJSON: argumentsJSON,
            argumentsHash: argumentsHash,
            status: status,
            createdAt: createdAt,
            startedAt: startedAt,
            updatedAt: updatedAt,
            latestOutput: latestOutput,
            outputByteCount: outputByteCount,
            processID: processID,
            cancelRequested: cancelRequested,
            completedAt: completedAt,
            result: result,
            errorMessage: errorMessage
        )
    }

    private static func encode(_ result: ToolCallResult) throws -> String {
        let data = try JSONEncoder().encode(result)
        return String(decoding: data, as: UTF8.self)
    }

    private static func decodeResult(_ value: String) -> ToolCallResult? {
        guard let data = value.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ToolCallResult.self, from: data)
    }
}
