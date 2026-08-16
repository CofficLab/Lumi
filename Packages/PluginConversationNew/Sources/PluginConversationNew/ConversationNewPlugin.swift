import KernelCore
import ProviderConversation
import ProviderToolbar
import SwiftUI

@MainActor
public final class ConversationNewPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.conversation-new"
    public let order = 80

    /// 对齐旧版 ConversationNewPlugin 的元数据：
    /// - name "New Chat Button"（旧版 LumiPluginLocalization）
    /// - policy .alwaysOn → .required（不可禁用）
    /// - stage .beta → .preview
    public var metadata: PluginMetadata {
        PluginMetadata(
            id: id,
            name: "New Chat Button",
            description: "在标题栏提供「新对话」按钮：点击取消当前选中对话，回到新会话状态。",
            version: "1.0.0",
            category: .chat,
            stage: .preview,
            policy: .required
        )
    }

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let toolbar = kernel.resolveProvider((any ToolbarProviding).self) else { return }
        // 挂载到整个 App 的标题栏工具栏右侧（与旧版 titleToolbarItems / .trailing 对齐），
        // 而不是 chat 的工具栏。
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
