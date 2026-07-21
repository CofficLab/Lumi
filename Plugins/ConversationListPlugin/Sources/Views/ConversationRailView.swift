import LumiCoreMessage
import LumiKernel
import LumiUI
import SuperLogKit
import SwiftUI
import os

/// Rail 面板视图
struct ConversationRailView: View, SuperLog {
    let kernel: LumiKernel
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var refreshTrigger = 0

    private let conversationsDidChangeNotification = Notification.Name("com.coffic.lumi.conversationsDidChange")

    // MARK: - SuperLog

    nonisolated public static let emoji = "💬"
    nonisolated(unsafe) public static var verbose = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "conversation-list.rail")

    private var conversations: (any ConversationManaging)? {
        kernel.conversations
    }

    private var conversationList: [LumiConversationSummary] {
        _ = refreshTrigger
        return conversations?.conversations ?? []
    }

    private func handleCreateConversation() {
        guard let conv = conversations else { return }
        do {
            _ = try conv.createConversation(title: nil)
            refreshTrigger += 1
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    var body: some View {
        contentView
            .alert("创建对话失败", isPresented: $showErrorAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "未知错误")
            }
    }

    @ViewBuilder
    private var contentView: some View {
        if let conv = conversations {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Chats")
                        .font(.headline)
                    Spacer()
                    Button(action: handleCreateConversation) {
                        Image(systemName: "plus")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                let list = conversationList
                if list.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "message")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        Text("No conversations")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(list) { conversation in
                        ConversationRow(
                            conversation: conversation,
                            isSelected: conv.selectedConversationID == conversation.id,
                            onSelect: {
                                conv.selectConversation(id: conversation.id)
                                refreshTrigger += 1
                            },
                            onDelete: {
                                conv.deleteConversation(id: conversation.id)
                                refreshTrigger += 1
                            }
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onReceive(NotificationCenter.default.publisher(for: conversationsDidChangeNotification)) { _ in
                refreshTrigger += 1
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text("Service unavailable")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}
