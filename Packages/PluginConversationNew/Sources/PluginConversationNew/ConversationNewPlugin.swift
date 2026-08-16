import KernelCore
import ProviderConversation
import ProviderToolbar
import SwiftUI

@MainActor
public final class ConversationNewPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.conversation-new"
    public let order = 80
    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let toolbar = kernel.resolveProvider((any ToolbarProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self) else { return }
        // 挂载到整个 App 的标题栏工具栏右侧（与旧版 titleToolbarItems / .trailing 对齐），
        // 而不是 chat 的工具栏。
        toolbar.addToolbarItems([
            ToolbarItem(id: "\(id).new-chat", title: "New Chat", placement: .trailing, order: 30) {
                Button {
                    if let conversationID = try? conversations.createConversation(title: nil, projectPath: nil, providerID: nil, modelName: nil) {
                        conversations.selectConversation(id: conversationID)
                    }
                } label: {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ToolbarProviding).self)?.removeToolbarItems(ids: ["\(id).new-chat"])
    }
}
