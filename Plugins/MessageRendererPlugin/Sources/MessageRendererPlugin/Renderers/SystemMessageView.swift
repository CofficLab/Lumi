import KernelLumi
import KernelLumi
import LumiUI
import SwiftUI

struct SystemMessageView: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    let verbosity: LumiResponseVerbosity

    private var isBrief: Bool { verbosity == .brief }

    var body: some View {
        MessageViewChrome(message: message, verbosity: verbosity) {
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