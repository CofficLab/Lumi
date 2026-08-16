import KernelCore
import ProviderChatSection
import ProviderConversation
import SwiftUI

@MainActor
public final class ConversationListPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.conversation-list"
    public let order = 81
    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        // The list is a chat-side contribution in the new architecture. The
        // actual chat message list remains owned by PluginMessageList.
        guard let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let chat = kernel.resolveProvider((any ChatSectionProviding).self) else { return }
        chat.addBarItems([ChatSectionBarItem(id: id, order: 20, placement: .toolbarTrailing) {
            ConversationListToolbar(conversations: conversations)
        }])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ChatSectionProviding).self)?.removeBarItem(id: id)
    }
}

@MainActor
private struct ConversationListToolbar: View {
    let conversations: any ConversationManaging
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.bubble")
            Text(conversations.currentTitle)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
    }
}
