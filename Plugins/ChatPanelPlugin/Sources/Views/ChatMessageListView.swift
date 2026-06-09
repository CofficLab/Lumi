import LumiCoreKit
import LumiUI
import SwiftUI

struct ChatMessageListView: View {
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

    var body: some View {
        let visibleMessages = messages.filter { $0.role != .tool }

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if visibleMessages.filter({ $0.role != .status }).isEmpty, !isSending {
                        ChatEmptyMessagesView(
                            automationLevel: automationLevel,
                            onQuickStart: onQuickStart
                        )
                        .frame(maxWidth: .infinity, minHeight: 320)
                    } else {
                        if hasEarlierMessages {
                            Button(action: onLoadEarlier) {
                                Text("Load earlier messages")
                                    .font(.appCaption)
                                    .foregroundColor(theme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
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
                        }

                        if isSending, !visibleMessages.contains(where: { $0.role == .status }) {
                            ChatTypingIndicator()
                                .id("typing-indicator")
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(theme.background.opacity(0.08))
            .onAppear {
                scrollToBottom(proxy: proxy, visibleMessages: visibleMessages)
            }
            .onChange(of: visibleMessages.last?.id) { _, _ in
                scrollToBottom(proxy: proxy, visibleMessages: visibleMessages)
            }
            .onChange(of: isSending) { _, _ in
                scrollToBottom(proxy: proxy, visibleMessages: visibleMessages)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, visibleMessages: [LumiChatMessage]) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.18)) {
                if let statusID = visibleMessages.last(where: { $0.role == .status })?.id {
                    proxy.scrollTo(statusID, anchor: .bottom)
                } else if isSending {
                    proxy.scrollTo("typing-indicator", anchor: .bottom)
                } else if let lastID = visibleMessages.last(where: { $0.role != .status })?.id {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }
}

private struct ChatEmptyMessagesView: View {
    @LumiTheme private var theme

    let automationLevel: LumiAutomationLevel
    let onQuickStart: (String) -> Void

    private var suggestions: [String] {
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

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.bubble.fill")
                .font(.appLargeTitle)
                .foregroundColor(theme.textSecondary)

            Text("Start a conversation")
                .font(.appTitle)
                .foregroundColor(theme.textPrimary)

            Text("Ask a question, paste context, or describe the task you want Lumi to handle.")
                .font(.appBody)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            VStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        onQuickStart(suggestion)
                    } label: {
                        Text(suggestion)
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

            Text("Thinking")
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)

            Spacer()
        }
        .padding(12)
        .frame(maxWidth: 360, alignment: .leading)
    }
}
