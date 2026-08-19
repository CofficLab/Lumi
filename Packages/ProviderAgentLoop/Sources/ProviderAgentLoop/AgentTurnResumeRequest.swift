import Foundation
import KitLLM
import ProviderConversation
import ProviderLifecycleHooks
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager

/// 恢复一次暂停回合的请求。
public struct AgentTurnResumeRequest: Sendable, Equatable {
    public let suspensionID: String
    public let answer: String

    public init(suspensionID: String, answer: String) {
        self.suspensionID = suspensionID
        self.answer = answer
    }
}
