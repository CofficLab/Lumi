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

    private var toolbarObserver: NewChatToolbarObserver?
    private var capability: NewChatCapabilityAdapter?
    private var viewModel: NewChatViewModel?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let toolbar = kernel.resolveProvider((any ToolbarProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let chat = kernel.resolveProvider((any ChatSectionProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolbarProviding, ConversationManaging or ChatSectionProviding from kernel")
            return
        }

        // 组装层：创建 Capability + ViewModel，注入视图。
        let capability = NewChatCapabilityAdapter(conversations: conversations)
        let viewModel = NewChatViewModel(capability: capability)
        self.capability = capability
        self.viewModel = viewModel

        let toolbarItemID = "\(id).new-chat"
        toolbarObserver = NewChatToolbarObserver(
            toolbar: toolbar,
            conversations: conversations,
            chat: chat,
            itemID: toolbarItemID
        ) {
            ToolbarItem(
                id: toolbarItemID,
                title: LumiPluginLocalization.string("New Chat", bundle: .module),
                placement: .trailing,
                category: .chat,
                order: 30
            ) {
                NewChatButton(viewModel: viewModel)
            }
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        toolbarObserver?.cancel()
        toolbarObserver = nil
        viewModel = nil
        capability = nil
        kernel.resolveProvider((any ToolbarProviding).self)?.removeToolbarItems(ids: ["\(id).new-chat"])
    }
}
