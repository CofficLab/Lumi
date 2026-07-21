import LumiKernel
import LumiUI
import SwiftUI

/// Message List Plugin
///
/// Provides the chat message list view in the ChatSection.
@MainActor
public final class MessageListPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.message-list"
    public let name = "Message List"
    public let order = 82

    public init() {}

    public func register(kernel: LumiKernel) throws {}

    public func boot(kernel: LumiKernel) async throws {}

    // MARK: - Chat Section Items

    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] {
        [
            ChatSectionItem(
                id: id,
                placement: .stack,
                fillsRemainingHeight: true
            ) {
                MessageListView()
            }
        ]
    }
}

// MARK: - Message List View

struct MessageListView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(spacing: 0) {
            // Placeholder message list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(sampleMessages) { message in
                        MessageBubble(message: message)
                    }
                }
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface)
    }

    private var sampleMessages: [SampleMessage] {
        [
            SampleMessage(role: "user", content: "Hello, how are you?"),
            SampleMessage(role: "assistant", content: "I'm doing great! How can I help you today?"),
            SampleMessage(role: "user", content: "Can you tell me about the weather?"),
            SampleMessage(role: "assistant", content: "The weather is sunny with a temperature of 72°F."),
        ]
    }
}

struct SampleMessage: Identifiable {
    let id = UUID()
    let role: String
    let content: String
}

struct MessageBubble: View {
    @LumiTheme private var theme
    let message: SampleMessage

    private var isUser: Bool {
        message.role == "user"
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(isUser ? "You" : "Assistant")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)

                Text(message.content)
                    .font(.body)
                    .foregroundColor(theme.textPrimary)
                    .padding(12)
                    .background(isUser ? theme.primary.opacity(0.1) : theme.surface.opacity(0.5))
                    .cornerRadius(12)
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }
}
