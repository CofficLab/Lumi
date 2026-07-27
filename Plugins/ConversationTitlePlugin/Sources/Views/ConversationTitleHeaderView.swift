import LumiKernel
import LumiUI
import SwiftUI

/// Header view displaying the current conversation title
struct ConversationTitleHeaderView: View {
    @ObservedObject var kernel: LumiKernel
    @LumiTheme private var theme

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

            Text(kernel.conversations?.currentTitle ?? "No conversation")
                .font(.appMicroEmphasized)
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)
        }
    }

    private var isSending: Bool {
        kernel.conversations?.isSending(for: kernel.conversations?.selectedConversationID) ?? false
    }
}
