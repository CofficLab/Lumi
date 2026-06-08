import LumiCoreKit
import LumiUI
import SwiftUI

struct ChatMessageListView: View {
    @LumiTheme private var theme

    let messages: [LumiChatMessage]
    let isSending: Bool
    let rendererForMessage: (LumiChatMessage) -> LumiMessageRendererItem?
    let rawMessageBinding: (UUID) -> Binding<Bool>
    let onUseAsDraft: (LumiChatMessage) -> Void

    var body: some View {
        let visibleMessages = messages.filter { $0.role != .tool }

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if visibleMessages.isEmpty {
                        ChatEmptyMessagesView()
                            .frame(maxWidth: .infinity, minHeight: 320)
                    } else {
                        ForEach(visibleMessages) { message in
                            ChatMessageBubble(
                                message: message,
                                renderer: rendererForMessage(message),
                                showRawMessage: rawMessageBinding(message.id),
                                onUseAsDraft: {
                                    onUseAsDraft(message)
                                }
                            )
                            .id(message.id)
                        }

                        if isSending {
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
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: visibleMessages.last?.id) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: isSending) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.18)) {
                if isSending {
                    proxy.scrollTo("typing-indicator", anchor: .bottom)
                } else if let lastID = messages.last(where: { $0.role != .tool })?.id {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }
}

private struct ChatEmptyMessagesView: View {
    @LumiTheme private var theme

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
