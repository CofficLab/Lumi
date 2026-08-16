import KernelCore
import LumiUI
import ProviderChatSection
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
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
        let rendering = kernel.resolveProvider((any MessageRenderingProviding).self)
        chat.addItems([ChatSectionItem(id: id, order: 100, fillsRemainingHeight: true) {
            MessageListView(conversations: conversations, messages: messages, rendering: rendering)
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
    let rendering: (any MessageRenderingProviding)?
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
                        MessageRow(
                            message: message,
                            verbosity: verbosity(for: conversationID),
                            rendering: rendering
                        )
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

    private func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity {
        conversations?.verbosity(for: conversationID) ?? .standard
    }
}

@MainActor
private struct MessageRow: View {
    let message: Message
    let verbosity: LumiResponseVerbosity
    let rendering: (any MessageRenderingProviding)?

    var body: some View {
        // 经渲染器注册表分发：无渲染器时兜底为纯文本行。
        if let renderer = rendering?.renderer(for: message) {
            renderer.render(message, verbosity)
        } else {
            fallbackRow
        }
    }

    private var fallbackRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: message.role == .user ? "person.circle.fill" : "sparkles")
                .foregroundStyle(message.role == .user ? Color.secondary : Color.accentColor)
                .frame(width: 22)
            Text(message.content)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
    }
}
