import LumiCoreMessage
import LumiKernel
import LumiUI
import SwiftUI

struct SystemMessageView: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    @Binding var showRawMessage: Bool

    var body: some View {
        MessageViewChrome(message: message, showRawMessage: $showRawMessage) {
            BorderedUtilityContent(tint: theme.textSecondary, role: .system) {
                Text(message.content)
                    .font(.appBody)
                    .foregroundColor(theme.textPrimary)
                    .textSelection(.enabled)
                    .lineSpacing(3)
            }
        }
    }
}
