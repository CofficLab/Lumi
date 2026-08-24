import Foundation

/// 多语句执行中单条语句的执行结果。
public struct StatementExecution: Identifiable, Sendable {
    public let id: UUID
    /// 已 trim 过的语句文本。
    public let sql: String
    /// 成功时返回查询结果；失败时 `errorMessage` 非空。
    public var result: QueryResult?
    public var errorMessage: String?
    /// 执行耗时（毫秒）。
    public var durationMs: Double

    public var succeeded: Bool { errorMessage == nil }

    public init(sql: String, result: QueryResult? = nil, errorMessage: String? = nil, durationMs: Double = 0) {
        self.id = UUID()
        self.sql = sql
        self.result = result
        self.errorMessage = errorMessage
        self.durationMs = durationMs
    }
}
