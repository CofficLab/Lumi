import Foundation
import ProviderMessage

/// 为一次 LLM 请求准备消息上下文。
///
/// 调用方不需要知道返回的是完整历史、摘要加最近消息，还是其他经过筛选的
/// 上下文。具体策略由实现方负责，完整聊天记录仍由 `MessageManaging` 保存。
@MainActor
public protocol LLMContextProviding: AnyObject, Sendable {
    func messagesForLLM(in conversationID: UUID) async -> [Message]
}

/// 不改变消息内容的透传实现。
///
/// 用于测试、宿主降级，以及上下文压缩插件尚未启用时保持原有行为。
@MainActor
public final class PassthroughLLMContextProvider: LLMContextProviding {
    private let messages: any MessageManaging

    public init(messages: any MessageManaging) {
        self.messages = messages
    }

    public func messagesForLLM(in conversationID: UUID) async -> [Message] {
        await messages.messagesForLLM(in: conversationID)
    }
}
