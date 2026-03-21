import Foundation
import MagicKit

// MARK: - 轮次中间件管线依赖

@MainActor
struct ConversationTurnMiddlewareEnvironment {
    let selectedConversationId: () -> UUID?
    let languagePreference: () -> LanguagePreference
    let maxDepth: Int
    let maxThinkingTextLength: Int
    let maxToolResultLength: Int
    let immediateStreamFlushChars: Int
    let immediateThinkingFlushChars: Int
    let streamUIFlushInterval: TimeInterval
    let thinkingUIFlushInterval: TimeInterval
    let captureThinkingContent: Bool
}

@MainActor
struct ConversationTurnMiddlewareMessageActions {
    let messages: () -> [ChatMessage]
    let appendMessage: (ChatMessage) -> Void
    let updateMessage: (ChatMessage, Int) -> Void
    let saveMessage: (ChatMessage, UUID) async -> Void
    let enqueueTurnProcessing: (UUID, Int) -> Void
    let executeToolAndContinue: (ToolCall, UUID, LanguagePreference) async -> Void
    let updateRuntimeState: (UUID) -> Void
}

@MainActor
struct ConversationTurnMiddlewareProjectionActions {
    let setPendingPermissionRequest: (PermissionRequest?, UUID) -> Void
    let setDepthWarning: (DepthWarning?, UUID) -> Void
    let onTurnFinishedUI: (UUID) -> Void
    let onTurnFailedUI: (UUID, String) -> Void

    let onStreamStartedUI: (UUID, UUID) -> Void
    let onStreamFirstTokenUI: (UUID, Double?) -> Void
    let onStreamFinishedUI: (UUID) -> Void
    let onThinkingStartedUI: (UUID) -> Void
    let setLastHeartbeatTime: (Date?) -> Void
    let setIsThinking: (Bool, UUID) -> Void
    let setThinkingText: (String, UUID) -> Void
    let appendThinkingText: (String, UUID) -> Void
}

// MARK: - 轮次中间件共享上下文

@MainActor
final class ConversationTurnMiddlewareContext {
    let runtimeStore: ConversationRuntimeStore
    let env: ConversationTurnMiddlewareEnvironment
    let actions: ConversationTurnMiddlewareMessageActions
    let projection: ConversationTurnMiddlewareProjectionActions

    let traceId: UUID
    let startedAt: Date

    init(
        runtimeStore: ConversationRuntimeStore,
        env: ConversationTurnMiddlewareEnvironment,
        actions: ConversationTurnMiddlewareMessageActions,
        projection: ConversationTurnMiddlewareProjectionActions,
        traceId: UUID = UUID(),
        startedAt: Date = Date()
    ) {
        self.runtimeStore = runtimeStore
        self.env = env
        self.actions = actions
        self.projection = projection
        self.traceId = traceId
        self.startedAt = startedAt
    }
}
