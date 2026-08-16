import KernelCore
import LumiUI
import ProviderChatSection
import ProviderConversation
import ProviderMessage
import SwiftUI

@MainActor
public final class MessageListPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.message-list"
    public let order = 82
    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self) else { return }
        let conversations = kernel.resolveProvider((any ConversationManaging).self)
        let messages = kernel.resolveProvider((any MessageManaging).self)
        chat.addItems([ChatSectionItem(id: id, order: 100, fillsRemainingHeight: true) {
            MessageListView(conversations: conversations, messages: messages)
        }])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ChatSectionProviding).self)?.removeItem(id: id)
    }
}

@MainActor
private struct MessageListView: View {
    let conversations: (any ConversationManaging)?
    let messages: (any MessageManaging)?
    @State private var revision = 0

    var body: some View {
        let conversationID = conversations?.selectedConversationID
        let rows = conversationID.map { messages?.messages(for: $0) ?? [] } ?? []
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if rows.isEmpty {
                    Text("Start a conversation")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ForEach(rows) { message in
                        MessageRow(message: message)
                    }
                }
            }
            .padding(12)
        }
        .id(revision)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                revision += 1
            }
        }
    }
}

@MainActor
private struct MessageRow: View {
    let message: Message

    var body: some View {
        let isUser = message.role == .user
        let bubbleRole: MessageBubbleRole = isUser ? .user : (message.isError ? .error : .assistant)
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: isUser ? "person.circle.fill" : "sparkles")
                .foregroundStyle(isUser ? Color.secondary : Color.accentColor)
                .frame(width: 22)
            Text(message.content)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .appMessageBubble(role: bubbleRole, isError: message.isError)
    }
}
