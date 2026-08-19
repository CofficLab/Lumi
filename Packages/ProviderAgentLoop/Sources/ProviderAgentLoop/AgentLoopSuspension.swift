import Foundation
import KitLLM
import ProviderConversation
import ProviderLifecycleHooks
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager

/// 一次工具/交互导致的回合暂停点。
///
/// `kind` 区分暂停原因（`toolApproval` / `askUser` 等），`payload` 是 JSON
/// 字符串（选项、问题等）。用户回答后经 `resumeTurn(in:request:)` 恢复。
public struct AgentLoopSuspension: Sendable, Equatable {
    public let suspensionID: String
    public let conversationID: UUID
    public let toolCallID: String?
    public let kind: String
    public let payload: String

    public init(
        suspensionID: String,
        conversationID: UUID,
        toolCallID: String? = nil,
        kind: String,
        payload: String
    ) {
        self.suspensionID = suspensionID
        self.conversationID = conversationID
        self.toolCallID = toolCallID
        self.kind = kind
        self.payload = payload
    }
}
