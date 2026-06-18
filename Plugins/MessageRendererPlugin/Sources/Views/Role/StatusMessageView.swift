import LumiCoreKit
import LumiUI
import SwiftUI

struct StatusMessageView: View {
    @LumiTheme private var theme
    @State private var isBreathing = false

    let message: LumiChatMessage

    var body: some View {
        CompactMessageHeaderView {
            HStack(alignment: .center, spacing: 8) {
                ChatAvatarView(kind: .status)
                    .scaleEffect(isBreathing ? 1.12 : 0.92)
                    .opacity(isBreathing ? 1.0 : 0.55)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isBreathing)
                    .onAppear { isBreathing = true }

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
