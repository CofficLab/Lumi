import Foundation
import KernelLumi

/// Builds the UI snapshot for one AgentTurn from ToolManaging records.
enum TurnActivityBuilder {
    static func build(
        turnID: UUID,
        conversationID: UUID,
        state: AgentTurnState,
        toolCalls: [LumiToolCallRecord]
    ) -> LumiTurnActivity {
        LumiTurnActivity(
            id: turnID,
            conversationID: conversationID,
            state: state,
            toolCalls: toolCalls.sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt {
                    return lhs.startedAt < rhs.startedAt
                }
                return lhs.id < rhs.id
            }
        )
    }
}
