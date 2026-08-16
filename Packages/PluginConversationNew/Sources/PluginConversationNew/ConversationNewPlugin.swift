import KernelCore
import ProviderChatSection
import ProviderConversation
import SwiftUI

@MainActor
public final class ConversationNewPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.conversation-new"
    public let order = 80
    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self) else { return }
        chat.addBarItems([ChatSectionBarItem(id: id, order: 10, placement: .toolbarLeading) {
            Button {
                if let conversationID = try? conversations.createConversation(title: nil, projectPath: nil, providerID: nil, modelName: nil) {
                    conversations.selectConversation(id: conversationID)
                }
            } label: {
                Label("New", systemImage: "plus")
            }
            .buttonStyle(.borderless)
        }])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ChatSectionProviding).self)?.removeBarItem(id: id)
    }
}
