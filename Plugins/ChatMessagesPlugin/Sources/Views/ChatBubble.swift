import LumiCoreKit
import LumiUI
import SwiftUI

public struct ChatBubble: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @EnvironmentObject private var conversationVM: LumiCoreKit.WindowConversationVM
    @EnvironmentObject private var timelineViewModel: WindowChatTimelineViewModel

    public let message: ChatMessage
    public let isLastMessage: Bool
    public let isStreaming: Bool

    private let messageRenderer: (ChatMessage, Binding<Bool>) -> AnyView?
    @State private var showRawMessage = false
    @State private var showDeleteConfirmation = false

    public init(
        message: ChatMessage,
        isLastMessage: Bool,
        isStreaming: Bool = false,
        messageRenderer: @escaping (ChatMessage, Binding<Bool>) -> AnyView? = { _, _ in nil }
    ) {
        self.message = message
        self.isLastMessage = isLastMessage
        self.isStreaming = isStreaming
        self.messageRenderer = messageRenderer
    }

    public var body: some View {
        ZStack {
            if let rendered = messageRenderer(message, $showRawMessage) {
                rendered
            } else {
                fallbackBubble
            }
        }
        .contextMenu {
            if message.role == .user, !message.content.isEmpty {
                Button {
                    conversationVM.enqueueText(message.content)
                } label: {
                    Label(String(localized: "Resend", bundle: .module), systemImage: "arrow.clockwise")
                }
            }

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label(String(localized: "Delete Message", bundle: .module), systemImage: "trash")
            }
        }
        .alert(String(localized: "Delete Message", bundle: .module), isPresented: $showDeleteConfirmation) {
            Button(String(localized: "Cancel", bundle: .module), role: .cancel) {}
            Button(String(localized: "Delete", bundle: .module), role: .destructive) {
                timelineViewModel.deleteMessage(message.id)
            }
        } message: {
            Text(String(localized: "Are you sure you want to delete this message? This action cannot be undone.", bundle: .module))
        }
    }

    private var fallbackBubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.content)
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .textSelection(.enabled)
        }
        .padding()
        .appSurface(style: .subtle, cornerRadius: 8)
    }
}
