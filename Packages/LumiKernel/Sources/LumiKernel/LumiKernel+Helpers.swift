import Foundation

// MARK: - UI 展示用便捷函数

extension LumiKernelContainer {
    /// UI 展示用对话标题。
    ///
    /// 解析优先级：
    /// 1. 已持久化的真实标题（`hasCustomTitle` 为真）；
    /// 2. 用户发送的第一条非空消息（仅 UI 展示，不持久化，超长截断为单行）；
    /// 3. 以上皆无时返回空字符串 `""`，由调用方决定占位文案（如 "Untitled"）。
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

        return ""
    }

    // MARK: - 内部辅助

    private static let uiTitleMaxLength = 40

    private static func firstUserMessageTitle(
        in conversationID: UUID,
        messageManaging: (any MessageManaging)?
    ) -> String? {
        guard let messageManaging else { return nil }
        let message = messageManaging.displayMessages(for: conversationID)
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
