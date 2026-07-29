import LumiKernel
import LumiKernel
import LumiUI
import SwiftUI

struct SystemMessageView: View {
    @Environment(\.lumiResponseVerbosity) private var verbosity
    @LumiTheme private var theme

    let message: LumiChatMessage
    @Binding var showRawMessage: Bool

    private var isBrief: Bool { verbosity == .brief }

    var body: some View {
        MessageViewChrome(message: message, showRawMessage: $showRawMessage) {
            Group {
                if isBrief {
                    Text(message.content)
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                        .textSelection(.enabled)
                } else {
                    BorderedUtilityContent(tint: theme.textSecondary, role: .system) {
                        systemContent
                    }
                }
            }
        }
    }

    private var systemContent: some View {
        Text(message.content)
            .font(.appBody)
            .foregroundColor(theme.textPrimary)
            .textSelection(.enabled)
            .lineSpacing(3)
    }
}
