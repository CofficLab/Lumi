import Foundation
import LumiCoreKit

@MainActor
enum ToolExecutorRuntimeBridge {
    static var loadMessages: (UUID) -> [ChatMessage] = { _ in [] }
    static var loadTurnPhase: (UUID) -> AgentTurnPhase = { _ in .idle }
    static var setTurnPhase: (AgentTurnPhase, UUID) -> Void = { _, _ in }
    static var tryAcquireConversationLock: (UUID) -> Bool = { _ in false }
    static var releaseConversationLock: (UUID) -> Void = { _ in }
    static var isConversationCancelled: (UUID) -> Bool = { _ in false }
    static var presentToolPermissionIfNeeded: (ChatMessage, UUID) async -> Bool = { _, _ in false }
    static var executeToolCalls: (ChatMessage, UUID) async -> ToolExecutionSummary = { _, _ in ToolExecutionSummary() }
    static var finishAgentTurn: (UUID, TurnEndReason) -> Void = { _, _ in }
    static var setConversationStatus: (UUID, String) -> Void = { _, _ in }
}
