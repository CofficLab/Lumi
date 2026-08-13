import Foundation
import KernelLumi

/// A display-ready snapshot of one agent turn's tool activity.
///
/// This is derived from ToolManaging records and AgentTurnManaging state;
/// it is not persisted and does not replace conversation messages.
struct LumiTurnActivity: Identifiable, Equatable, Sendable {
    let id: UUID
    let conversationID: UUID
    let state: AgentTurnState
    let toolCalls: [LumiToolCallRecord]

    var totalCount: Int { toolCalls.count }

    var completedCount: Int {
        toolCalls.reduce(into: 0) { count, record in
            if record.completedAt != nil { count += 1 }
        }
    }

    var failedCount: Int {
        toolCalls.reduce(into: 0) { count, record in
            if record.resultIsError { count += 1 }
        }
    }

    var totalDuration: TimeInterval? {
        let durations = toolCalls.compactMap(\.duration)
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +)
    }
}
