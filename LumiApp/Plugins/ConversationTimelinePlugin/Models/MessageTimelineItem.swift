import Foundation
import MagicKit

/// 用于时间线展示的轻量数据结构，从 `ChatMessage` 映射而来
struct MessageTimelineItem: Identifiable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    let hasToolCalls: Bool
    let isError: Bool
    let providerId: String?
    let modelName: String?
    let inputTokens: Int?
    let outputTokens: Int?
}
