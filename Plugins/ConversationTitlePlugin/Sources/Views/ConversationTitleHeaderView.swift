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
        .onReceive(NotificationCenter.default.publisher(for: .lumiMessagesDidChange)) { notification in
            if let conversationID = notification.lumiConversationID,
               conversationID != kernel.conversations?.selectedConversationID {
                return
            }
            messageVersion += 1
        }
    }

    /// 标题显示逻辑统一委托给 LumiKernel 级 ``LumiKernelContainer/uiTitle(for:)``。
    private var displayTitle: String {
        _ = messageVersion

        guard let conversations = kernel.conversations,
              let conversationID = conversations.selectedConversationID else {
            return "No conversation"
        }
        return kernel.uiTitle(for: conversationID)
    }

    private var isSending: Bool {
        kernel.conversations?.isSending(for: kernel.conversations?.selectedConversationID) ?? false
    }
}
