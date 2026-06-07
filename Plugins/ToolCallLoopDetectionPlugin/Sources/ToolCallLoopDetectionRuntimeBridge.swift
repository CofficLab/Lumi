import Foundation
import LumiCoreKit

@MainActor
enum ToolCallLoopDetectionRuntimeBridge {
    static var loadMessages: (UUID) -> [ChatMessage] = { _ in [] }
    static var loadTurnPhase: (UUID) -> AgentTurnPhase = { _ in .idle }
    static var saveMessage: (ChatMessage, UUID) -> Void = { _, _ in }
    static var setTurnPhase: (AgentTurnPhase, UUID) -> Void = { _, _ in }
    static var isConversationCancelled: (UUID) -> Bool = { _ in false }
    static var markConversationCancelled: (UUID) -> Void = { _ in }
    static var releaseConversationLock: (UUID) -> Void = { _ in }
    static var finishAgentTurn: (UUID, TurnEndReason) -> Void = { _, _ in }
    static var setConversationStatus: (UUID, String) -> Void = { _, _ in }
}
