import LumiCoreKit
import LumiUI
import SwiftUI

struct MessageViewChrome<Content: View>: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    @Binding var showRawMessage: Bool
    var showsResendButton = false
    var showsHeader = true
    var errorTransportDetails: ResolvedErrorTransportDetails?
    @State private var didCopy = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showsHeader {
                CompactMessageHeaderView {
                    HStack(alignment: .center, spacing: 6) {
                        ChatAvatarView(kind: MessageViewHelpers.avatarKind(for: message.role))
                        AppIdentityRow(
                            title: MessageViewHelpers.headerTitle(for: message),
                            metadata: MessageViewHelpers.metadataItems(for: message)
                        )
                    }
                } trailing: {
                    HStack(alignment: .center, spacing: 12) {
                        CopyMessageButton(
                            content: MessageViewHelpers.copyContent(for: message),
                            showFeedback: $didCopy
                        )

                        if showsResendButton, !message.content.isEmpty {
                            ResendMessageButton(message: message)
                        }

                        AppIdentityRow(
                            title: MessageViewHelpers.formatTimestamp(message.createdAt),
                            titleColor: theme.textSecondary
                        )

                        if let errorTransportDetails, errorTransportDetails.hasTransportDetails {
                            ErrorTransportDetailsButton(details: errorTransportDetails)
                        }

                        MessageInfoButton(message: message)
                    }
                }
            }

            content()

            if showRawMessage {
                Text(MessageViewHelpers.rawDescription(for: message))
                    .font(.appMonoCaption)
                    .foregroundColor(theme.textSecondary)
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appSurface(style: .panel, cornerRadius: 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
