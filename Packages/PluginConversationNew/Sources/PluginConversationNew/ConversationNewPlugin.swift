import os
import KernelCore
import SuperLogKit
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

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let toolbar = kernel.resolveProvider((any ToolbarProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ToolbarProviding from kernel")
            return
        }

        toolbar.addToolbarItems([
            ToolbarItem(id: "\(id).new-chat", title: "New Chat", placement: .trailing, order: 30) {
                NewChatButton(kernel: kernel)
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ToolbarProviding).self)?.removeToolbarItems(ids: ["\(id).new-chat"])
    }
}
