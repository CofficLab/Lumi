import KitAgentTool
import KernelCore
import KitLocalization
import LumiUI
import KitMarkdown
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageSender
import ProviderToolManager
import LumiUI
import SwiftUI

struct StatusMessageView: View {
    @LumiTheme private var theme

    let message: Message
    let verbosity: ResponseVerbosity
    @State private var showInfoPopover = false

    var body: some View {
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

                if message.role != .status {
                    MessageInfoButton(
                        message: message,
                        isPresented: $showInfoPopover
                    )
                }
            }
        }
    }
}
