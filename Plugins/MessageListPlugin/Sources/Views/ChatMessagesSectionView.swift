import LumiKernel
import LumiUI
import SwiftUI

/// Chat 消息列表 section 视图（占位实现）
struct ChatMessagesSectionView: View {
    @ObservedObject var coordinator: ChatSectionCoordinator

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Placeholder message bubbles
                ForEach(0..<3, id: \.self) { index in
                    MessageBubblePlaceholder(role: index == 0 ? .user : .assistant, index: index)
                }
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.green.opacity(0.05))
    }
}

// MARK: - Message Bubble Placeholder

private struct MessageBubblePlaceholder: View {
    let role: MessageRole
    let index: Int

    enum MessageRole {
        case user
        case assistant
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(role == .user ? "You" : "Assistant")
                    .font(.appMicroEmphasized)
                    .foregroundColor(.secondary)

                Spacer()

                Text("12:3\(index)")
                    .font(.appMicro)
                    .foregroundColor(.secondary)
            }

            Text(placeholderText)
                .font(.appBody)
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: 680, alignment: .leading)
        .background(role == .user ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }

    private var placeholderText: String {
        switch index {
        case 0:
            return "Hello! How can I help you today?"
        case 1:
            return "This is a sample message from the \(role == .user ? "user" : "assistant"). It demonstrates how messages are displayed in the chat interface."
        default:
            return "Another message in the conversation thread."
        }
    }
}
