import LumiCoreKit
import LumiUI
import MarkdownKit
import SwiftUI

struct ChatMessageListView: View {
    private static let bottomAnchorID = "chat-message-list-bottom"

    @LumiTheme private var theme

    let messages: [LumiChatMessage]
    let isSending: Bool
    let hasEarlierMessages: Bool
    let rendererForMessage: (LumiChatMessage) -> LumiMessageRendererItem?
    let rawMessageBinding: (UUID) -> Binding<Bool>
    let onUseAsDraft: (LumiChatMessage) -> Void
    let onResend: (LumiChatMessage) -> Void
    let onDelete: (LumiChatMessage) -> Void
    let onLoadEarlier: () -> Void
    let onQuickStart: (String) -> Void
    let automationLevel: LumiAutomationLevel
    let verbosity: LumiResponseVerbosity

    var body: some View {
        let visibleMessages = messages.filter(isVisibleMessage)

        Group {
            if visibleMessages.filter({ $0.role != .status }).isEmpty, !isSending {
                ChatEmptyMessagesView(
                    automationLevel: automationLevel,
                    onQuickStart: onQuickStart
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                messageListContent(visibleMessages: visibleMessages)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(chatListBackground)
    }

    private func isVisibleMessage(_ message: LumiChatMessage) -> Bool {
        if message.role == .tool {
            return false
        }
        return true
    }

    /// 消息列表的专属背景：纵向微渐变营造深度层次感。
    private var chatListBackground: some View {
        LinearGradient(
            colors: [
                theme.background.opacity(0.45),
                theme.surface,
                theme.elevatedSurface.opacity(0.3),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func messageListContent(visibleMessages: [LumiChatMessage]) -> some View {
        ScrollViewReader { proxy in
            List {
                if hasEarlierMessages {
                    Button(action: onLoadEarlier) {
                        Text(verbatim: LumiPluginLocalization.string("Load earlier messages", bundle: .module))
                            .font(.appCaption)
                            .foregroundColor(theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .listRowSeparator(.hidden)
                }

                ForEach(visibleMessages) { message in
                    ChatMessageBubble(
                        message: message,
                        renderer: rendererForMessage(message),
                        showRawMessage: rawMessageBinding(message.id),
                        onUseAsDraft: {
                            onUseAsDraft(message)
                        },
                        onResend: message.role == .user ? { onResend(message) } : nil,
                        onDelete: { onDelete(message) }
                    )
                    .id(message.id)
                    .padding(.horizontal, ChatMessageListLayout.messageRowHorizontalPadding)
                    .padding(.vertical, ChatMessageListLayout.messageRowVerticalPadding)
                    .listRowInsets(ChatMessageListLayout.messageRowInsets)
                    .listRowSeparator(.hidden)
                }

                if isSending,
                   !visibleMessages.contains(where: { $0.metadata["isTransientStatus"] == "true" }) {
                    ChatTypingIndicator()
                        .id("typing-indicator")
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                }

                bottomAnchor
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.preferOuterScroll, ChatMessageListLayout.prefersOuterScrollForMarkdown)
            .onAppear {
                scrollToBottom(proxy: proxy, animated: false, settleLayout: true)
            }
            .onChange(of: visibleMessages.last?.id) { _, _ in
                scrollToBottom(proxy: proxy, animated: true, settleLayout: true)
            }
            .onChange(of: isSending) { _, sending in
                guard sending else { return }
                scrollToBottom(proxy: proxy, animated: true, settleLayout: true)
            }
        }
    }

    private var bottomAnchor: some View {
        Color.clear
            .frame(height: 1)
            .id(Self.bottomAnchorID)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .accessibilityHidden(true)
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool, settleLayout: Bool = false) {
        func performScroll(animated: Bool) {
            if animated {
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
            }
        }

        DispatchQueue.main.async {
            performScroll(animated: animated)
            guard settleLayout else { return }

            DispatchQueue.main.async {
                performScroll(animated: false)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                performScroll(animated: false)
            }
        }
    }
}

private struct ChatEmptyMessagesView: View {
    @LumiTheme private var theme

    let automationLevel: LumiAutomationLevel
    let onQuickStart: (String) -> Void

    private var suggestionKeys: [String] {
        switch automationLevel {
        case .chat:
            [
                "Explain this concept in simple terms",
                "Help me brainstorm ideas",
                "Review this paragraph for clarity"
            ]
        case .build:
            [
                "Scan the project and summarize the architecture",
                "Find where authentication is implemented",
                "Suggest a safe refactor plan"
            ]
        case .autonomous:
            [
                "Investigate this bug and propose a fix",
                "Implement the feature described below",
                "Run the necessary tools and report back"
            ]
        }
    }

    private func localized(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.bubble.fill")
                .font(.appLargeTitle)
                .foregroundColor(theme.textSecondary)

            Text(verbatim: LumiPluginLocalization.string("Start a conversation", bundle: .module))
                .font(.appTitle)
                .foregroundColor(theme.textPrimary)

            Text(verbatim: LumiPluginLocalization.string("Ask a question, paste context, or describe the task you want Lumi to handle.", bundle: .module))
                .font(.appBody)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            VStack(spacing: 8) {
                ForEach(suggestionKeys, id: \.self) { key in
                    let suggestion = localized(key)
                    Button {
                        onQuickStart(suggestion)
                    } label: {
                        Text(verbatim: suggestion)
                            .font(.appCaption)
                            .foregroundColor(theme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(theme.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: 420)

            AppButton(
                localized("Onboarding Guide"),
                style: .ghost,
                size: .small
            ) {
                NotificationCenter.default.post(name: .lumiShowOnboarding, object: nil)
            }
            .accessibilityHint(localized("Onboarding Guide Hint"))
        }
        .padding(28)
    }
}

private struct ChatTypingIndicator: View {
    @LumiTheme private var theme

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.78)

            Text(verbatim: LumiPluginLocalization.string("Thinking", bundle: .module))
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)

            Spacer()
        }
        .padding(12)
        .frame(maxWidth: 360, alignment: .leading)
    }
}
