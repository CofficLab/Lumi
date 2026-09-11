import SwiftUI
import os

/// 待发消息列表视图。
struct PendingMessageListView: View {
    private static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.conversation-pending-message",
        category: "PendingMessageListView"
    )

    @ObservedObject var viewModel: PendingMessageViewModel

    var body: some View {
        Group {
            if let conversationID = viewModel.selectedConversationID,
               !viewModel.pendingMessages.isEmpty {
                let _ = Self.logger.debug("body evaluated: conversation=\(conversationID.uuidString.prefix(8)), pending=\(viewModel.pendingMessages.count)")
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.pendingMessages) { message in
                            HStack(spacing: 6) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                Text(message.content)
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                    .foregroundColor(.secondary)
                                if !message.imageAttachments.isEmpty {
                                    Label("\(message.imageAttachments.count)", systemImage: "photo")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                if !message.fileAttachments.isEmpty {
                                    Label("\(message.fileAttachments.count)", systemImage: "doc")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button {
                                    viewModel.cancelPendingMessage(id: message.id)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 2)
            }
        }
        .onAppear {
            let selectedConversation = viewModel.selectedConversationID?.uuidString.prefix(8) ?? "nil"
            Self.logger.info("view appeared: selectedConversation=\(selectedConversation)")
        }
    }
}
