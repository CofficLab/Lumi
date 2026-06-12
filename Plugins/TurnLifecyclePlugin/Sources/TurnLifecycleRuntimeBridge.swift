import Foundation
import LumiCoreKit

@MainActor
enum TurnLifecycleRuntimeBridge {
    static var loadMessages: (UUID) -> [ChatMessage] = { _ in [] }
    static var loadTurnPhase: (UUID) -> AgentTurnPhase = { _ in .idle }
    static var setTurnPhase: (AgentTurnPhase, UUID) -> Void = { _, _ in }
    static var releaseConversationLock: (UUID) -> Void = { _ in }
    static var finishAgentTurn: (UUID, TurnEndReason) -> Void = { _, _ in }
}
