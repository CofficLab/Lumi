import LumiUI
import ProviderConversation
import ProviderMessage
import SwiftUI

struct MessageViewChrome<Content: View>: View {
    @LumiTheme private var theme

    var capability: (any MessageRendererCapability)? = nil
    let message: Message
    var showsResendButton = false
    /// 失败消息是否提供「重试」入口（错误消息行）。是否真能重试由回合状态决定。
    var showsRetryButton = false
    var showsHeader = true
    var errorTransportDetails: ResolvedErrorTransportDetails?
    let verbosity: ResponseVerbosity
    @State private var didCopy = false
    @State private var showThinkingPopover = false
    @State private var showInfoPopover = false
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

    /// 操作按钮的可见性：悬停、思考 popover 打开、复制反馈显示中任一为真。
    /// V3（detailed 模式）下始终显示，无需 hover。
    private var showsActions: Bool {
        verbosity == .detailed || isRowHovered || showThinkingPopover || showInfoPopover || didCopy
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

    var body: some View {
        let thinking = thinkingContent
        return Group {
            if isBrief {
                messageBody(thinking: thinking)
            } else {
                messageBody(thinking: thinking)
            }
        }
        .appThemedAppearance()
    }

    @ViewBuilder
    private func messageBody(thinking: String?) -> some View {
        VStack(alignment: .leading, spacing: isBrief ? 0 : 4) {
            if MessageHeaderVisibility.isVisible(showsHeader: showsHeader, verbosity: verbosity) {
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
                        // V3 (detailed) 下操作按钮与时间戳始终显示；V2 (standard) 下仅在悬停时物化。
                        if showsActions {
                            CopyMessageButton(
                                contentProvider: { MessageViewHelpers.copyContent(for: message) },
                                showFeedback: $didCopy
                            )
                        }

                        if showsActions, showsResendButton, capability != nil, !message.content.isEmpty {
                            ResendMessageButton(capability: capability, message: message)
                        }

                        if showsActions, showsRetryButton, capability != nil {
                            RetryTurnButton(capability: capability, message: message)
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
                            .help(pluginLocalization.string("思考过程"))
                            .popover(isPresented: $showThinkingPopover, arrowEdge: .bottom) {
                                ThinkingPopoverContent(text: thinking!)
                            }
                        }

                        if showsActions {
                            AppIdentityRow(
                                title: MessageViewHelpers.formatTimestamp(message.createdAt),
                                titleColor: theme.textSecondary
                            )
                        }

                        if showsActions, let errorTransportDetails, errorTransportDetails.hasTransportDetails {
                            ErrorTransportDetailsButton(details: errorTransportDetails)
                        }

                        if showsActions {
                            MessageInfoButton(
                                message: message,
                                isPresented: $showInfoPopover
                            )
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
}

/// 消息头（头像 + 名称/模型 + 操作按钮）的显示决策。
///
/// 纯逻辑、便于单元测试：视图只问「这一行要不要画头」，不自己拼级别判断。
///
/// - V1（brief）：不画头，内容和 V2 一样靠 `AssistantMessageView` 升格复用。
/// - V6（standardNoHeader）：布局与 V2 完全一致，**只**去掉消息头。
enum MessageHeaderVisibility {
    static func isVisible(showsHeader: Bool, verbosity: ResponseVerbosity) -> Bool {
        guard showsHeader else { return false }
        switch verbosity {
        case .brief, .standardNoHeader:
            return false
        case .standard, .detailed, .zcode, .chatGPT:
            return true
        }
    }
}
