import Foundation
import ProviderAgentLoop

/// Agent 回合状态所需的最小能力。
@MainActor
public protocol MessageListAgentLoopCapability: AnyObject {
    func state(for conversationID: UUID) -> AgentLoopState
}

@MainActor
public final class MessageListAgentLoopCapabilityAdapter: MessageListAgentLoopCapability {
    private let agentTurn: any AgentLoopProviding
    public init(agentTurn: any AgentLoopProviding) { self.agentTurn = agentTurn }
    public func state(for conversationID: UUID) -> AgentLoopState {
        agentTurn.state(for: conversationID)
    }
}