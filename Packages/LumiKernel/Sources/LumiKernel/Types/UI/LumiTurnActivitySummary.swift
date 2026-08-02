import Foundation

/// Display summary for one AgentTurn, sourced from ToolManaging records.
public struct LumiTurnActivitySummary: Equatable, Sendable {
    public let turnID: UUID
    public let totalCount: Int
    public let completedCount: Int
    public let failedCount: Int
    public let totalDuration: TimeInterval?

    public init(
        turnID: UUID,
        totalCount: Int,
        completedCount: Int,
        failedCount: Int,
        totalDuration: TimeInterval?
    ) {
        self.turnID = turnID
        self.totalCount = totalCount
        self.completedCount = completedCount
        self.failedCount = failedCount
        self.totalDuration = totalDuration
    }
}
