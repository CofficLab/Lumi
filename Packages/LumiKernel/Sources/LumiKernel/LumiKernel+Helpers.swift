import Foundation

// MARK: - UI 展示用便捷函数

extension LumiKernelContainer {
    /// 重新发送一条已保存的用户消息。
    public func resendMessage(id: UUID, in conversationID: UUID) async {
        await messageSender?.resendMessage(id: id, in: conversationID)
    }

    /// UI 展示用对话标题。
    ///
    /// 解析优先级：
    /// 1. 已持久化的真实标题（`hasCustomTitle` 为真）；
    /// 2. 用户发送的第一条非空消息（仅 UI 展示，不持久化，超长截断为单行）；
    /// 3. 以上皆无时返回按数据库顺序生成的默认标题。
    ///
    /// 实现直接调用 kernel 的对话能力（`conversations`）与消息能力（`messageManager`）。
    public func uiTitle(for conversationID: UUID) -> String {
        guard let conversations = conversations else { return "" }

        if let summary = conversations.conversations.first(where: { $0.id == conversationID }),
           summary.hasCustomTitle {
            return summary.displayTitle
        }

        if let fallback = Self.firstUserMessageTitle(in: conversationID, messageManaging: messageManager) {
            return fallback
        }

        return Self.defaultConversationTitle(for: conversationID, in: conversations.conversations)
    }

    // MARK: - 内部辅助

    private static let uiTitleMaxLength = 40

    private static func defaultConversationTitle(
        for conversationID: UUID,
        in conversations: [LumiConversationSummary]
    ) -> String {
        let databaseOrder = conversations
            .sorted {
                if $0.createdAt == $1.createdAt {
                    return $0.id.uuidString < $1.id.uuidString
                }
                return $0.createdAt < $1.createdAt
            }
            .firstIndex(where: { $0.id == conversationID })
            .map { $0 + 1 } ?? conversations.count + 1

        return "新对话\(databaseOrder)"
    }

    private static func firstUserMessageTitle(
        in conversationID: UUID,
        messageManaging: (any MessageManaging)?
    ) -> String? {
        guard let messageManaging else { return nil }
        let message = messageManaging.cachedDisplayMessages(for: conversationID)
            .first {
                $0.role == .user
                    && !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        guard let content = message?.content.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            return nil
        }
        return truncateTitle(content)
    }

    private static func truncateTitle(_ text: String) -> String {
        let collapsed = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.count > uiTitleMaxLength else { return collapsed }
        let end = collapsed.index(collapsed.startIndex, offsetBy: uiTitleMaxLength)
        return String(collapsed[..<end]) + "…"
    }
}
