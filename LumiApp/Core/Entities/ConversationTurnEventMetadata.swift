import Foundation
import MagicKit

extension ConversationTurnEvent {
    var debugName: String {
        switch self {
        case .responseReceived: return "responseReceived"
        case .streamChunk: return "streamChunk"
        case .streamEvent: return "streamEvent"
        case .streamStarted: return "streamStarted"
        case .streamFinished: return "streamFinished"
        case .toolResultReceived: return "toolResultReceived"
        case .permissionRequested: return "permissionRequested"
        case .permissionDecision: return "permissionDecision"
        case .maxDepthReached: return "maxDepthReached"
        case .finalStepToolCalls: return "finalStepToolCalls"
        case .completed: return "completed"
        case .error: return "error"
        case .shouldContinue: return "shouldContinue"
        }
    }
}

extension StreamEventType {
    var shouldForwardToTurnPipelineEvent: Bool {
        switch self {
        case .ping, .contentBlockStart, .contentBlockStop, .messageDelta, .signatureDelta, .thinkingDelta:
            return true
        case .messageStart, .messageStop, .unknown, .contentBlockDelta, .inputJsonDelta, .textDelta:
            return false
        }
    }
}
