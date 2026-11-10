import AppKit
import CoreGraphics
import Foundation
import LumiUI
import ProviderConversation
import ProviderMessage
import SwiftUI

struct ChatGPTUserMessageView: View {
    @LumiTheme private var theme

    let capability: any MessageRendererCapability
    @ObservedObject var stateViewModel: MessageRendererStateViewModel
    let message: Message
    let verbosity: ResponseVerbosity

    @State private var isHovered = false
    @FocusState private var hasKeyboardFocus: Bool

    static func usesChatGPTPresentation(verbosity: ResponseVerbosity) -> Bool {
        verbosity == .chatGPT
    }

    static func contentPresentation(
        for blocks: [CollapsedContentBlock]
    ) -> ChatGPTUserContentPresentation {
        blocks.isEmpty ? .plainText : .collapsedChips
    }

    private var showsActions: Bool {
        isHovered || hasKeyboardFocus
    }

    var body: some View {
        let attachments = message.cachedDecodedAttachments
        let hasAttachments = !attachments.imageData.isEmpty || !attachments.fileAttachments.isEmpty
        let showsBubble = ChatGPTUserBubbleStyle.hasVisibleBubble(
            content: message.content,
            hasAttachments: hasAttachments
        )
        let blocks = CollapsedContentBlockMetadata.normalizedBlocks(
            from: message.metadata,
            contentLength: message.content.count
        )

        return ChatGPTUserMessageLayout {
            VStack(alignment: .trailing, spacing: 8) {
                attachmentSection(attachments: attachments)

                if showsBubble {
                    bubbleBody(blocks: blocks)
                    actionBar
                        .frame(height: ChatGPTUserBubbleStyle.actionBarHeight)
                        .opacity(showsActions ? 1 : 0)
                        .allowsHitTesting(showsActions)
                        .accessibilityHidden(!showsActions)
                }
            }
        }
        .focusable()
        .focused($hasKeyboardFocus)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private func bubbleBody(blocks: [CollapsedContentBlock]) -> some View {
        Group {
            switch Self.contentPresentation(for: blocks) {
            case .plainText:
                Text(message.content)
                    .font(.appBody)
                    .foregroundColor(message.isError ? theme.error : theme.textPrimary)
                    .lineSpacing(ChatGPTUserBubbleStyle.bodyLineSpacing)
                    .lineLimit(ChatGPTUserBubbleStyle.bodyLineLimit)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            case .collapsedChips:
                CollapsedContentChips(text: message.content, blocks: blocks)
            }
        }
        .accessibilityIdentifier(ChatGPTRendererAccessibilityIdentifiers.userBubbleBody)
        .padding(.horizontal, ChatGPTUserBubbleStyle.horizontalPadding)
        .padding(.vertical, ChatGPTUserBubbleStyle.verticalPadding)
        .background(
            theme.surface,
            in: RoundedRectangle(
                cornerRadius: ChatGPTUserBubbleStyle.cornerRadius,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: ChatGPTUserBubbleStyle.cornerRadius,
                style: .continuous
            )
            .strokeBorder(theme.textSecondary.opacity(0.12), lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            Text(" ")
                .font(.system(size: 1))
                .frame(width: 1, height: 1)
                .accessibilityIdentifier(ChatGPTRendererAccessibilityIdentifiers.userBubble)
                .allowsHitTesting(false)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 4) {
            Button {
                LumiPasteboard.copyString(ChatGPTUserBubbleStyle.copyText(for: message.content))
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 14))
                    .foregroundColor(theme.textSecondary)
                    .frame(
                        width: ChatGPTUserBubbleStyle.actionButtonSize,
                        height: ChatGPTUserBubbleStyle.actionButtonSize
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(ChatGPTRendererAccessibilityIdentifiers.userCopyButton)
            .accessibilityLabel(pluginLocalization.string("Copy"))
            .help(pluginLocalization.string("Copy"))

            Button {
                Task {
                    await ChatGPTUserMessageActions.resend(
                        message: message,
                        capability: capability
                    )
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14))
                    .foregroundColor(theme.textSecondary)
                    .frame(
                        width: ChatGPTUserBubbleStyle.actionButtonSize,
                        height: ChatGPTUserBubbleStyle.actionButtonSize
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(ChatGPTRendererAccessibilityIdentifiers.userResendButton)
            .accessibilityLabel(pluginLocalization.string("重新发送"))
            .help(pluginLocalization.string("重新发送该消息"))
        }
    }

    @ViewBuilder
    private func attachmentSection(
        attachments: MessageAttachmentDecodeCache.Decoded
    ) -> some View {
        if !attachments.imageData.isEmpty || !attachments.fileAttachments.isEmpty {
            VStack(alignment: .trailing, spacing: 8) {
                if !attachments.imageData.isEmpty {
                    AppImagePreviewGrid(imageDataList: attachments.imageData)
                }
                if !attachments.fileAttachments.isEmpty {
                    MessageFileAttachmentChips(attachments: attachments.fileAttachments)
                }
            }
        }
    }
}

enum ChatGPTUserContentPresentation: Equatable {
    case plainText
    case collapsedChips
}

@MainActor
enum ChatGPTUserMessageActions {
    static func resend(
        message: Message,
        capability: any MessageRendererCapability
    ) async {
        await capability.resendMessage(
            content: message.content,
            conversationID: message.conversationID
        )
    }
}

struct ChatGPTUserMessageLayout: Layout {
    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard let subview = subviews.first else { return .zero }
        guard let availableWidth = proposal.width, availableWidth.isFinite, availableWidth > 0 else {
            return subview.sizeThatFits(proposal)
        }

        let maximumWidth = Self.maximumBubbleWidth(for: availableWidth)
        let measured = subview.sizeThatFits(
            ProposedViewSize(width: maximumWidth, height: proposal.height)
        )
        return CGSize(width: availableWidth, height: measured.height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard let subview = subviews.first else { return }
        let maximumWidth = Self.maximumBubbleWidth(for: bounds.width)
        let measured = subview.sizeThatFits(
            ProposedViewSize(width: maximumWidth, height: proposal.height)
        )
        let width = Self.constrainedWidth(
            idealWidth: measured.width,
            availableWidth: maximumWidth
        )

        subview.place(
            at: CGPoint(x: bounds.maxX - width, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: width, height: measured.height)
        )
    }

    static func maximumBubbleWidth(for contentWidth: CGFloat) -> CGFloat {
        guard contentWidth.isFinite, contentWidth > 0 else { return 0 }
        let fraction: CGFloat = contentWidth < 480 ? 0.92 : 0.8
        return min(contentWidth, min(560, contentWidth * fraction))
    }

    static func constrainedWidth(idealWidth: CGFloat, availableWidth: CGFloat) -> CGFloat {
        guard idealWidth.isFinite, availableWidth.isFinite, availableWidth > 0 else { return 0 }
        return max(0, min(idealWidth, availableWidth))
    }
}

enum ChatGPTUserBubbleStyle {
    static let cornerRadius: CGFloat = 18
    static let horizontalPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 10
    static let bodyLineHeight: CGFloat = 24
    static let bodyLineLimit: Int? = nil
    static let collapsesLongPlainText = false
    static let actionButtonSize: CGFloat = 28
    static let actionBarHeight: CGFloat = 32

    static let bodyLineSpacing: CGFloat = {
        fontMetricsLock.lock()
        defer { fontMetricsLock.unlock() }
        let font = NSFont.systemFont(ofSize: 15)
        let fontLineHeight = font.ascender - font.descender + font.leading
        return max(0, bodyLineHeight - fontLineHeight)
    }()

    private static let fontMetricsLock = NSLock()

    static func hasVisibleBubble(content: String, hasAttachments: Bool) -> Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func copyText(for content: String) -> String {
        content
    }
}

enum ChatGPTRendererAccessibilityIdentifiers {
    static let userBubble = "lumi.message.chatgpt.user-bubble"
    static let userBubbleBody = "lumi.message.chatgpt.user-bubble-body"
    static let userCopyButton = "lumi.message.chatgpt.user-copy"
    static let userResendButton = "lumi.message.chatgpt.user-resend"
}
