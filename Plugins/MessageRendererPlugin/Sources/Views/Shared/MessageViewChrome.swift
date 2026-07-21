import LumiCoreMessage
import LumiKernel
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
    @State private var showThinkingPopover = false
    @ViewBuilder let content: () -> Content

    private var thinkingContent: String? {
        if let reasoning = message.reasoningContent, !reasoning.isEmpty {
            return reasoning
        }
        if let thinking = message.metadata["thinkingContent"], !thinking.isEmpty {
            return thinking
        }
        return nil
    }

    private var hasThinkingContent: Bool {
        thinkingContent != nil
    }

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

                        if hasThinkingContent {
                            AppIconButton(
                                systemImage: "brain",
                                tint: showThinkingPopover ? theme.textPrimary : theme.textSecondary,
                                size: .regular,
                                isActive: showThinkingPopover
                            ) {
                                showThinkingPopover.toggle()
                            }
                            .help(LumiPluginLocalization.string("思考过程", bundle: .module))
                            .popover(isPresented: $showThinkingPopover, arrowEdge: .bottom) {
                                ThinkingPopoverContent(text: thinkingContent!)
                            }
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

struct ThinkingPopoverContent: View {
    @LumiTheme private var theme
    let text: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(LumiPluginLocalization.string("思考过程", bundle: .module))
                    .font(.appCaptionEmphasized)
                    .foregroundColor(theme.textSecondary)

                Text(text)
                    .font(.appMonoCaption)
                    .foregroundColor(theme.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
        }
        .frame(width: 420)
        .frame(maxHeight: 360)
    }
}
