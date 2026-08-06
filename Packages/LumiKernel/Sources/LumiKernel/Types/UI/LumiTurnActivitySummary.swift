import Foundation

/// Display summary for one AgentTurn, sourced from ToolManaging records.
///
/// UI 层（如 MessageList 插件的 turn activity 行、AgentTurnList 插件的摘要视图）
/// 使用该类型渲染 turn 的进度概览。
///
/// 两种数据来源：
/// 1. `turnID` + `ToolManaging.toolCalls(for:)` → 通过 `init(turnID:...)` 手动构造。
/// 2. `AgentTurnRecord` + `ToolManaging.toolCalls(for:)` → 通过 `init(record:...)` 便捷构造。
public struct LumiTurnActivitySummary: Equatable, Sendable {
    public let turnID: UUID
    public let totalCount: Int
    public let completedCount: Int
    public let failedCount: Int
    public let totalDuration: TimeInterval?
    /// Whether this turn ended in failure (`.failed` state or had any tool error).
    /// UI 可据此显示不同的状态图标（如红色感叹号）。
    public let isFailed: Bool

    public init(
        turnID: UUID,
        totalCount: Int,
        completedCount: Int,
        failedCount: Int,
        totalDuration: TimeInterval?,
        isFailed: Bool = false
    ) {
        self.turnID = turnID
        self.totalCount = totalCount
        self.completedCount = completedCount
        self.failedCount = failedCount
        self.totalDuration = totalDuration
        self.isFailed = isFailed
    }

    /// Constructs a summary from a persisted `AgentTurnRecord`, overriding
    /// tool-call counts with the live `toolCalls` snapshot if provided.
    ///
    /// - Parameters:
    ///   - record: The turn's metadata record (source of truth for state/tokens).
    ///   - toolCalls: Optional live tool-call snapshot. When `nil`, the summary
    ///     falls back to the counters stored on the record.
    public init(record: AgentTurnRecord, toolCalls: [LumiToolCallRecord]? = nil) {
        let total: Int
        let completed: Int
        let failed: Int
        let duration: TimeInterval?

        if let toolCalls {
            total = toolCalls.count
            completed = toolCalls.filter { $0.completedAt != nil }.count
            failed = toolCalls.filter(\.resultIsError).count
            let durations = toolCalls.compactMap(\.duration)
            duration = durations.isEmpty ? nil : durations.reduce(0, +)
        } else {
            total = record.toolCallCount
            completed = record.toolCallCompletedCount
            failed = 0
            duration = record.endedAt.map { $0.timeIntervalSince(record.startedAt) }
        }

        self.turnID = record.id
        self.totalCount = total
        self.completedCount = completed
        self.failedCount = failed
        self.totalDuration = duration
        self.isFailed = {
            if case .failed = record.state { return true }
            return failed > 0
        }()
    }
}
