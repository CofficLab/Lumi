import LumiKernel
import LumiKernel
import LumiUI
import SwiftUI

struct StatusMessageView: View {
    @Environment(\.lumiResponseVerbosity) private var verbosity
    @LumiTheme private var theme

    let message: LumiChatMessage

    var body: some View {
        if verbosity == .brief {
            Text(message.content)
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
                .lineLimit(2)
                .textSelection(.enabled)
        } else {
            CompactMessageHeaderView {
            HStack(alignment: .center, spacing: 8) {
                ChatAvatarView(kind: .status)
                    .overlay(alignment: .center) {
                        PulseRipple(color: theme.primary)
                    }

                Text(message.content)
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Spacer(minLength: 0)
            }
        } trailing: {
            HStack(alignment: .center, spacing: 12) {
                AppIdentityRow(
                    title: MessageViewHelpers.formatTimestamp(message.createdAt),
                    titleColor: theme.textSecondary
                )

                MessageInfoButton(message: message)
            }
            }
        }
    }
}
