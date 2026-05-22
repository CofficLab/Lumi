import Foundation
import ToolKit

/// 聊天时间线渲染态（仅 UI 层，按会话隔离，不落库）。
struct ConversationRenderState {
    var selectedConversationId: UUID?

    /// 已持久化的稳定消息行
    var persistedMessages: [ChatMessage] = []
    /// 已进入发送队列但尚未持久化的消息行。
    var queuedMessages: [ChatMessage] = []
    /// 活跃流式行（高频可变，仅一条）
    var activeStreamingMessage: ChatMessage?

    var hasMoreMessages: Bool = false
    var isLoadingMore: Bool = false
    var totalMessageCount: Int = 0
    var oldestLoadedTimestamp: Date?
    var toolOutputsByToolCallID: [String: [ChatMessage]] = [:]
    var loadedToolCallIDs = Set<String>()
    var loadingToolCallIDs = Set<String>()

    var shouldAutoFollow: Bool = true
    var hasPerformedInitialScroll: Bool = false
}
