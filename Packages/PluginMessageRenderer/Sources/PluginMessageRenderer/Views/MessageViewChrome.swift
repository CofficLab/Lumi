import AppKit
import KernelCore
import LumiUI
import ProviderConversation
import ProviderMessage
import ProviderMessageSender
import SwiftUI

struct MessageViewChrome<Content: View>: View {
    @LumiTheme private var theme

    var kernel: KernelCoreContainer? = nil
    let message: Message
    var showsResendButton = false
    var showsHeader = true
    var errorTransportDetails: ResolvedErrorTransportDetails?
    let verbosity: LumiResponseVerbosity
    @State private var didCopy = false
    @State private var showThinkingPopover = false
    /// 行级悬停态:操作按钮组仅在悬停该行时物化(滚动重物化时每行
    /// 少构建 ~5 个按钮子树),popover 打开或复制反馈期间保持可见。
    @State private var isRowHovered = false
    /// 悬停进入防抖:滚动时光标下的行快速进出,立即物化按钮会造成
    /// hover 风暴;停留 150ms 才显示(标准菜单式交互),离开立即隐藏。
    @State private var hoverDebounceTask: Task<Void, Never>?
    @ViewBuilder let content: () -> Content

    private var isBrief: Bool {
        verbosity == .brief
    }

    /// 操作按钮的可见性:悬停、思考 popover 打开、复制反馈显示中任一为真。
    private var showsActions: Bool {
        isRowHovered || showThinkingPopover || didCopy
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
        // 局部 let:thinkingContent/tokenDisplayText 历史上每次求值计算 2 次
        // (hasThinkingContent + 显式读取),滚动重物化时被高频触发。
        let thinking = thinkingContent
        let tokenText = tokenDisplayText
        return Group {
            if isBrief {
                messageBody(thinking: thinking, tokenText: tokenText)
                    .contextMenu { briefContextMenu }
            } else {
                messageBody(thinking: thinking, tokenText: tokenText)
            }
        }
        .appThemedAppearance()
    }

    @ViewBuilder
    private func messageBody(thinking: String?, tokenText: String?) -> some View {
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
                        // 操作按钮仅在悬停时物化(见 showsActions);
                        // 时间戳与 token 信息是纯文本,常驻。
                        if showsActions {
                            CopyMessageButton(
                                contentProvider: { MessageViewHelpers.copyContent(for: message) },
                                showFeedback: $didCopy
                            )
                        }

                        if showsActions, showsResendButton, let kernel, !message.content.isEmpty {
                            ResendMessageButton(kernel: kernel, message: message)
                        }

                        if showsActions, thinking != nil, verbosity != .detailed {
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
                                ThinkingPopoverContent(text: thinking!)
                            }
                        }

                        AppIdentityRow(
                            title: MessageViewHelpers.formatTimestamp(message.createdAt),
                            titleColor: theme.textSecondary
                        )

                        if let tokenInfo = tokenText {
                            AppIdentityRow(
                                title: tokenInfo,
                                titleColor: theme.textSecondary
                            )
                        }

                        if showsActions, let errorTransportDetails, errorTransportDetails.hasTransportDetails {
                            ErrorTransportDetailsButton(details: errorTransportDetails)
                        }

                        if showsActions {
                            MessageInfoButton(message: message)
                        }
                    }
                }
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onHover { hovering in
            if hovering {
                hoverDebounceTask?.cancel()
                hoverDebounceTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(150))
                    guard !Task.isCancelled else { return }
                    isRowHovered = true
                }
            } else {
                hoverDebounceTask?.cancel()
                isRowHovered = false
            }
        }
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
                    try? await kernel.resolveProvider((any MessageSendingProviding).self)?
                        .sendMessage(message.content, conversationID: message.conversationID)
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

