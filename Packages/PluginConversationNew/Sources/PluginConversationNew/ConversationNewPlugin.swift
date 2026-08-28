import os
import KernelCore
import KitSuperLog
import ProviderChatSection
import ProviderConversation
import ProviderToolbar
import SwiftUI

@MainActor
public final class ConversationNewPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.conversation-new", category: "ConversationNew")

    public let id = "com.coffic.lumi.plugin.conversation-new"
    public let order = 80
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.conversation-new",
        name: "Conversation New",
        description: "",
        category: .chat,
        stage: .stable,
        policy: .alwaysOn
    )

    /// 对齐旧版 ConversationNewPlugin 的元数据：
    /// - name "New Chat Button"（旧版 LumiPluginLocalization）
    /// - policy .alwaysOn → .required（不可禁用）
    /// - stage .beta → .preview

    private var selectedConversationObserver: (any SelectedConversationObserverHandle)?
    private var chatSectionObserver: (any ChatSectionProvidingObserverHandle)?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let toolbar = kernel.resolveProvider((any ToolbarProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let chat = kernel.resolveProvider((any ChatSectionProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolbarProviding, ConversationManaging or ChatSectionProviding from kernel")
            return
        }

        let toolbarItemID = "\(id).new-chat"
        let syncToolbarItem: @MainActor () -> Void = { [weak toolbar, weak conversations, weak chat] in
            guard let toolbar, let conversations, let chat else { return }
            let shouldShow = chat.isVisible && conversations.selectedConversationID != nil
            let isShown = toolbar.toolbarItems.contains { $0.id == toolbarItemID }
            if shouldShow, !isShown {
                toolbar.addToolbarItems([
                    ToolbarItem(id: toolbarItemID, title: LumiPluginLocalization.string("New Chat", bundle: .module), placement: .trailing, order: 30) {
                        NewChatButton(kernel: kernel)
                    },
                ])
            } else if !shouldShow, isShown {
                toolbar.removeToolbarItems(ids: [toolbarItemID])
            }
        }

        selectedConversationObserver = conversations.addSelectedConversationObserver { _ in
            syncToolbarItem()
        }
        chatSectionObserver = chat.addObserver { _ in
            syncToolbarItem()
        }
        syncToolbarItem()
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        selectedConversationObserver?.cancel()
        selectedConversationObserver = nil
        chatSectionObserver?.cancel()
        chatSectionObserver = nil
        kernel.resolveProvider((any ToolbarProviding).self)?.removeToolbarItems(ids: ["\(id).new-chat"])
    }
}
