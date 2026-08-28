import Foundation

/// 分页游标:以「最后消息时间 + id」唯一定位一页的末尾,用于稳定翻页。
struct ConversationPageCursor {
    let lastMessageAt: Date
    let id: UUID
}
