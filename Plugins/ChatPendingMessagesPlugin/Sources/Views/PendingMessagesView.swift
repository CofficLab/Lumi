import LumiCoreKit
import SwiftUI

public struct PendingMessagesView: View {
    @EnvironmentObject private var conversationVM: WindowConversationVM

    public init() {}

    public var body: some View {
        let messages = conversationVM.currentPendingMessages()
        if messages.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(PendingMessagesRuntime.title.isEmpty ? String(localized: "Waiting to Send", bundle: .module) : PendingMessagesRuntime.title)
                        .font(.system(size: 11, weight: .medium))
                    Text("(\(messages.count))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                }

                ForEach(messages, id: \.id) { message in
                    PendingMessageRow(message: message) {
                        conversationVM.removePendingMessage(id: message.id)
                    }
                }
            }
            .padding(10)
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

public struct PendingMessageRow: View {
    public let message: ChatMessage
    public let onRemove: (() -> Void)?

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "hourglass")
                .font(.system(size: 9))
                .foregroundColor(.secondary.opacity(0.6))

            Text(message.content.prefix(80))
                .font(.system(size: 11))
                .lineLimit(1)

            Spacer()

            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .medium))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}
