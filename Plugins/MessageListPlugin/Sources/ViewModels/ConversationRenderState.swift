import Foundation
import LumiCoreKit
import AgentToolKit

/// 聊天时间线渲染态（仅 UI 层，按会话隔离，不落库）。
public struct ConversationRenderState {
    public var selectedConversationId: UUID?

    /// 已持久化的稳定消息行
    public var persistedMessages: [ChatMessage] = []
    /// 已进入发送队列但尚未持久化的消息行。
    public var queuedMessages: [ChatMessage] = []
    /// 活跃流式行（高频可变，仅一条）
    public var activeStreamingMessage: ChatMessage?

    public var hasMoreMessages: Bool = false
    public var isLoadingMore: Bool = false
    public var totalMessageCount: Int = 0
    public var oldestLoadedTimestamp: Date?
    public var loadedToolCallIDs = Set<String>()
    public var loadingToolCallIDs = Set<String>()
}
