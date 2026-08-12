import Foundation

/// 查询历史中的一条记录。
public struct QueryHistoryEntry: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let sql: String
    public let configName: String
    public let database: String
    public let executedAt: Date

    public init(id: UUID = UUID(), sql: String, configName: String, database: String, executedAt: Date = Date()) {
        self.id = id
        self.sql = sql
        self.configName = configName
        self.database = database
        self.executedAt = executedAt
    }
}
