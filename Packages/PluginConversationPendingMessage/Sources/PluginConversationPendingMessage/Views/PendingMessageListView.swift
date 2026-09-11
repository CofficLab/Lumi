import SwiftUI
import Foundation

/// 待发消息列表视图。
struct PendingMessageListView: View {
    let box: MessageSendingBox
    let selection: ConversationSelectionBox
    @State private var selectedConversationID: UUID?
    @State private var selectionRevision = 0
    @State private var selectionObserverHandle: (any ConversationSelectionBox.ObserverHandle)?
    @State private var sendingRevision = 0
    @State private var sendingObserverHandle: (any MessageSendingBox.ObserverHandle)?

    var body: some View {
        let _ = selectionRevision
        let _ = sendingRevision
        Group {
            // 仅当选中会话有待发消息时显示。
            if let conversationID = selectedConversationID {
                let pending = box.sender.pendingMessages(for: conversationID)
                if !pending.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(pending) { message in
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
                                    box.sender.cancelPendingMessage(id: message.id, in: conversationID)
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
        }
        .onAppear {
            guard selectionObserverHandle == nil else { return }
            selectedConversationID = selection.selectedConversationID
            selectionObserverHandle = selection.addObserver { event in
                guard case let .selectedConversationChanged(id) = event else { return }
                selectedConversationID = id
                selectionRevision &+= 1
            }
        }
        .onDisappear {
            selectionObserverHandle?.cancel()
            selectionObserverHandle = nil
        }
        .onAppear {
            guard sendingObserverHandle == nil else { return }
            sendingObserverHandle = box.addObserver { _ in
                sendingRevision &+= 1
            }
        }
        .onDisappear {
            sendingObserverHandle?.cancel()
            sendingObserverHandle = nil
        }
    }
}
