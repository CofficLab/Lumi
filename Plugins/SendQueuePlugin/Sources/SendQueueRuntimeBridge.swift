import Foundation
import LumiCoreKit

@MainActor
enum SendQueueRuntimeBridge {
    static var loadMessages: (UUID) -> [AgentChatMessage] = { _ in [] }
    static var loadTurnPhase: (UUID) -> AgentTurnPhase = { _ in .idle }
    static var setTurnPhase: (AgentTurnPhase, UUID) -> Void = { _, _ in }
    static var tryAcquireConversationLock: (UUID) -> Bool = { _ in false }
    static var releaseConversationLock: (UUID) -> Void = { _ in }
    static var isConversationCancelled: (UUID) -> Bool = { _ in false }
    static var clearConversationCancelled: (UUID) -> Void = { _ in }
    static var dequeueNextPendingMessage: (UUID) -> AgentChatMessage? = { _ in nil }
    static var runSendPreparePipeline: (UUID, AgentChatMessage) async -> [String] = { _, _ in [] }
    static var storeTransientSystemPrompts: ([String], UUID) -> Void = { _, _ in }

    static var inFlightConversationIds = Set<UUID>()
}
