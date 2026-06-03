import LumiCoreKit
import LumiUI
import SwiftUI

public struct ChatMessagesView: View {
    @EnvironmentObject private var conversationVM: LumiCoreKit.WindowConversationVM
    @State private var refreshVersion = 0

    public init() {}

    public var body: some View {
        let messages = conversationVM.currentDisplayMessages()

        Group {
            if !conversationVM.hasSelectedConversation {
                EmptyStateView()
            } else if messages.isEmpty {
                EmptyMessagesView()
            } else {
                MessageListView(messages: messages)
            }
        }
        .id(refreshVersion)
        .onChange(of: conversationVM.selectedConversationId) { _, _ in
            refreshVersion += 1
        }
        .onChange(of: conversationVM.statusVersion) { _, _ in
            refreshVersion += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("messageSaved"))) { notification in
            guard let conversationId = notification.userInfo?["conversationId"] as? UUID,
                  conversationId == conversationVM.selectedConversationId
            else { return }
            refreshVersion += 1
        }
    }
}
