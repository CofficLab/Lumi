import Foundation

/// `ConversationTurnVM` 内部按会话维护的轮次可变状态。
struct ConversationTurnContext {
    var currentDepth: Int = 0
    var pendingToolCalls: [ToolCall] = []
    var currentProviderId: String = ""
    var chainStartedAt: Date?
    var consecutiveEmptyToolTurns: Int = 0
    var lastToolSignature: String?
    var repeatedToolSignatureCount: Int = 0
    var recentToolSignatures: [String] = []
}
