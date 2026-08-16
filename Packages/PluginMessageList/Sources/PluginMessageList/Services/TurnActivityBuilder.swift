import Foundation
import ProviderAgentLoop
import ProviderToolManager

/// Builds the UI snapshot for one AgentTurn from ToolManager records.
enum TurnActivityBuilder {
    static func build(
        turnID: UUID,
        conversationID: UUID,
        state: AgentTurnState,
        toolCalls: [ToolCallRecord]
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
