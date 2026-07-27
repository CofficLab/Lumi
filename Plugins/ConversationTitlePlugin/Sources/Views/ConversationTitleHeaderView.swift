import Combine
import LumiKernel
import LumiUI
import SwiftUI

/// Header view displaying the current conversation title
struct ConversationTitleHeaderView: View {
    @ObservedObject var kernel: LumiKernel
    @LumiTheme private var theme

    /// Bumped whenever messages change so the UI-only fallback title stays in sync.
    @State private var messageVersion = 0

    /// Maximum number of characters shown for the auto-derived (first user message) title.
    private static let maxFallbackTitleLength = 40

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.appMicro)
                .foregroundColor(theme.primary)
                .overlay {
                    if isSending {
                        PulseRipple(color: theme.primary)
                    }
                }

            Text(displayTitle)
                .font(.appMicroEmphasized)
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .lumiMessagesDidChange)) { _ in
            messageVersion += 1
        }
    }

    /// 标题显示逻辑：
    /// 1. 若对话已有真实标题，优先显示。
    /// 2. 否则在 UI 层面（不持久化）回退显示用户发送的第一条消息，过长则截断。
    private var displayTitle: String {
        _ = messageVersion

        guard let conversations = kernel.conversations else {
            return "No conversation"
        }

        let title = conversations.currentTitle
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasRealTitle = !trimmed.isEmpty && trimmed != "Untitled" && trimmed != "No conversation"

        if hasRealTitle {
            return title
        }

        // 无真实标题：回退到用户发送的第一条消息（仅 UI 显示，不写入存储）。
        if let fallback = firstUserMessageText {
            return fallback
        }

        return trimmed.isEmpty ? "No conversation" : title
    }

    /// 当前对话中用户发送的第一条非空消息文本，用于无标题时的 UI 回退显示。
    private var firstUserMessageText: String? {
        guard let conversations = kernel.conversations,
              let conversationID = conversations.selectedConversationID,
              let messageManager = kernel.messageManager else {
            return nil
        }
        let message = messageManager.displayMessages(for: conversationID)
            .first {
                $0.role == .user
                    && !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        guard let content = message?.content.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            return nil
        }
        return Self.truncated(content)
    }

    /// 将文本压缩为单行并截断到指定长度，超出部分以省略号结尾。
    private static func truncated(_ text: String) -> String {
        let collapsed = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.count > maxFallbackTitleLength else {
            return collapsed
        }
        let end = collapsed.index(collapsed.startIndex, offsetBy: maxFallbackTitleLength)
        return String(collapsed[..<end]) + "…"
    }

    private var isSending: Bool {
        kernel.conversations?.isSending(for: kernel.conversations?.selectedConversationID) ?? false
    }
}
