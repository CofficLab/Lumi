import AppKit
import LumiKernel
import LumiUI
import SwiftUI

struct MessageViewChrome<Content: View>: View {
    @LumiTheme private var theme

    var kernel: LumiKernel? = nil
    let message: LumiChatMessage
    var showsResendButton = false
    var showsHeader = true
    var errorTransportDetails: ResolvedErrorTransportDetails?
    let verbosity: LumiResponseVerbosity
    @State private var didCopy = false
    @State private var showThinkingPopover = false
    @ViewBuilder let content: () -> Content

    private var isBrief: Bool {
        verbosity == .brief
    }

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

    private var tokenDisplayText: String? {
        guard let input = message.inputTokenCount,
              let output = message.outputTokenCount else {
            return nil
        }
        let inputFormatted = formatTokenCount(input)
        let outputFormatted = formatTokenCount(output)
        return "\(inputFormatted)/\(outputFormatted) tokens"
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1000 {
            let k = Double(count) / 1000.0
            if k >= 10 {
                return String(format: "%.0fk", k)
            } else {
                return String(format: "%.1fk", k)
            }
        }
        return String(count)
    }

    var body: some View {
        Group {
            if isBrief {
                messageBody.contextMenu { briefContextMenu }
            } else {
                messageBody
            }
        }
        .appThemedAppearance()
    }

    @ViewBuilder
    private var messageBody: some View {
        VStack(alignment: .leading, spacing: isBrief ? 0 : 4) {
            if showsHeader && !isBrief {
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

                        if showsResendButton, let kernel, !message.content.isEmpty {
                            ResendMessageButton(kernel: kernel, message: message)
                        }

                        if hasThinkingContent, isBrief {
                            AppIconButton(
                                systemImage: "brain",
                                tint: showThinkingPopover ? theme.textPrimary : theme.textSecondary,
                                size: .compact,
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

                        if let tokenInfo = tokenDisplayText {
                            AppIdentityRow(
                                title: tokenInfo,
                                titleColor: theme.textSecondary
                            )
                        }

                        if let errorTransportDetails, errorTransportDetails.hasTransportDetails {
                            ErrorTransportDetailsButton(details: errorTransportDetails)
                        }

                        MessageInfoButton(message: message)
                    }
                }
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var briefContextMenu: some View {
        Button {
            copyMessageContent()
        } label: {
            Label("复制消息", systemImage: "doc.on.doc")
        }

        if showsResendButton, let kernel, !message.content.isEmpty {
            Button {
                Task {
                    await kernel.resendMessage(id: message.id, in: message.conversationID)
                }
            } label: {
                Label("重新发送", systemImage: "arrow.clockwise")
            }
        }
    }

    private func copyMessageContent() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(MessageViewHelpers.copyContent(for: message), forType: .string)
    }
}

