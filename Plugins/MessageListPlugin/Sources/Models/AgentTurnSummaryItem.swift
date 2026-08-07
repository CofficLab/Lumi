import Foundation
import LumiKernel

/// One compact V1 row: a persisted AgentTurn paired with its user-facing
/// terminal (or latest recoverable) message.
struct AgentTurnSummaryItem: Identifiable, Equatable, Sendable {
    let record: AgentTurnRecord
    let message: LumiChatMessage

    var id: UUID { record.id }
}
