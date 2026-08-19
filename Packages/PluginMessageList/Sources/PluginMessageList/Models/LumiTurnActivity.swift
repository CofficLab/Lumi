import Foundation
import ProviderAgentLoop
import ProviderToolManager

/// A display-ready snapshot of one agent turn's tool activity.
///
/// Derived from ToolManager records and AgentTurn state; not persisted and
/// does not replace conversation messages. 复刻自旧版 `LumiTurnActivity`，
/// 记录类型由旧版 `LumiToolCallRecord` 换成新版 `ToolCallRecord`（字段已对齐）。
struct LumiTurnActivity: Identifiable, Equatable, Sendable {
    let id: UUID
    let conversationID: UUID
    let state: AgentLoopState
    let toolCalls: [ToolCallRecord]

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
