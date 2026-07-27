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

    /// 标题显示逻辑（委托给 LumiKernel 级 ``LumiKernelContainer/uiTitle(for:)``）：
    /// 1. 持久化真实标题；2. 否则回退到用户首条消息（UI-only，截断）；3. 否则占位 "Untitled"。
    private var displayTitle: String {
        _ = messageVersion

        guard let conversations = kernel.conversations,
              let conversationID = conversations.selectedConversationID else {
            return "No conversation"
        }
        let title = kernel.uiTitle(for: conversationID)
        return title.isEmpty ? "Untitled" : title
    }

    private var isSending: Bool {
        kernel.conversations?.isSending(for: kernel.conversations?.selectedConversationID) ?? false
    }
}
