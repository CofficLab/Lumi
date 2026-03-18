import Foundation
import CoreGraphics

/// 聊天时间线渲染态（仅 UI 层，按会话隔离，不落库）。
struct ConversationRenderState {
    var selectedConversationId: UUID?

    /// 已持久化的稳定消息行
    var persistedMessages: [ChatMessage] = []
    /// 活跃流式行（高频可变，仅一条）
    var activeStreamingMessage: ChatMessage?

    var hasMoreMessages: Bool = false
    var isLoadingMore: Bool = false
    var totalMessageCount: Int = 0
    var oldestLoadedTimestamp: Date?
    var toolOutputsByToolCallID: [String: [ChatMessage]] = [:]
    var loadedToolCallIDs = Set<String>()
    var loadingToolCallIDs = Set<String>()

    var isNearBottom: Bool = true
    var shouldAutoFollow: Bool = true
    var contentBottomY: CGFloat = 0
    var viewportBottomY: CGFloat = 0
    var hasPerformedInitialScroll: Bool = false
}
