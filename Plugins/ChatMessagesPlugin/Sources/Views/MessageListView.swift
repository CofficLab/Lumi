import LumiCoreKit
import LumiUI
import SwiftUI

public struct MessageListView: View {
    private let messages: [ChatMessage]
    private let messageRenderer: (ChatMessage, Binding<Bool>) -> AnyView?

    public init(
        messages: [ChatMessage],
        messageRenderer: @escaping (ChatMessage, Binding<Bool>) -> AnyView? = { _, _ in nil }
    ) {
        self.messages = messages
        self.messageRenderer = messageRenderer
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(messages) { message in
                    ChatBubble(message: message, messageRenderer: messageRenderer)
                        .id(message.id)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
        }
    }
}
