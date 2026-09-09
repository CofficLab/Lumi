import Foundation
import ProviderAgentLoop

/// Agent 回合状态所需的最小能力。
@MainActor
protocol MessageListAgentLoopCapability: AnyObject {
    func state(for conversationID: UUID) -> AgentLoopState
}

@MainActor
final class MessageListAgentLoopCapabilityAdapter: MessageListAgentLoopCapability {
    private let agentTurn: any AgentLoopProviding

    init(agentTurn: any AgentLoopProviding) {
        self.agentTurn = agentTurn
    }

    func state(for conversationID: UUID) -> AgentLoopState {
        agentTurn.state(for: conversationID)
    }
}
