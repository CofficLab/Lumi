import LumiCoreMessage
import LumiUI
import SwiftUI

/// Message Bubble View
///
/// Displays a single chat message.
struct MessageBubble: View {
    @LumiTheme private var theme
    let message: LumiChatMessage

    private var isUser: Bool {
        message.role == .user
    }

    private var senderName: String {
        isUser ? "You" : "Assistant"
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(senderName)
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
