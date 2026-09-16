import Foundation
import ProviderAgentLoop
import ProviderMessage

/// 构造自动重试时间线系统消息的辅助工具。
///
/// 消息带有时间线事件元数据，由 `core-agent-loop-retry` 渲染器展示，
/// 且不进入 LLM 上下文。
enum AgentLoopRetryTimeline {
    static func message(
        conversationID: UUID,
        failedTurnID: UUID,
        attempt: Int,
        maxAttempts: Int,
        failure: AgentLoopFailure
    ) -> Message {
        var metadata: [String: String] = [
            MessageTimelineEvent.metadataKey: MessageTimelineEvent.agentLoopRetry,
            MessageTimelineEvent.agentLoopRetryAttemptKey: "\(attempt)",
            MessageTimelineEvent.agentLoopRetryMaxAttemptsKey: "\(maxAttempts)",
            MessageTimelineEvent.agentLoopRetryReasonKey: failure.message,
            MessageTimelineEvent.agentLoopRetryKindKey: failure.kind.rawValue,
        ]
        if let providerID = failure.providerID {
            metadata[MessageTimelineEvent.agentLoopRetryProviderIDKey] = providerID
        }
        if let modelName = failure.modelName {
            metadata[MessageTimelineEvent.agentLoopRetryModelNameKey] = modelName
        }
        if let statusCode = failure.httpStatusCode {
            metadata[MessageTimelineEvent.agentLoopRetryHTTPStatusCodeKey] = "\(statusCode)"
        }

        let reason = failure.message.isEmpty ? failure.kind.rawValue : failure.message
        return Message(
            conversationID: conversationID,
            role: .system,
            content: "正在重试 Agent 回合（\(attempt)/\(maxAttempts)）：\(reason)",
            turnID: failedTurnID,
            metadata: metadata,
            providerID: failure.providerID,
            modelName: failure.modelName,
            rawErrorDetail: failure.message,
            httpStatusCode: failure.httpStatusCode,
            renderKind: MessageTimelineEvent.agentLoopRetryRenderKind,
            preferredRendererID: "core-agent-loop-retry"
        )
    }
}