import KernelCore
import KitSuperLog
import os
import ProviderChatSection
import ProviderConversation
import ProviderMessage
import ProviderToast

/// 在 ChatToolbar 贡献当前会话的 HTML 导出入口。
@MainActor
public final class ConversationExportPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.conversation-export",
        category: "ConversationExport"
    )

    public let id = "com.coffic.lumi.plugin.conversation-export"
    public let order = 86
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.conversation-export",
        name: "Conversation Export",
        description: "Export the current conversation as a self-contained HTML file.",
        category: .chat,
        stage: .stable,
        policy: .enabledByDefault
    )

    private var viewModel: ConversationExportViewModel?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let messages = kernel.resolveProvider((any MessageManaging).self) else {
            Self.logger.error("\(Self.t)Missing ChatSection, Conversation, or Message provider")
            return
        }

        viewModel?.cancel()
        chat.removeBarItem(id: "\(id).toolbar")

        let viewModel = ConversationExportViewModel(
            conversations: conversations,
            messages: messages,
            toast: kernel.resolveProvider((any ToastProviding).self)
        )
        self.viewModel = viewModel

        chat.addBarItems([
            ChatSectionBarItem(
                id: "\(id).toolbar",
                order: 90,
                placement: .toolbarTrailing
            ) {
                ConversationExportToolbarView(viewModel: viewModel)
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        viewModel?.cancel()
        viewModel = nil
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).toolbar")
    }
}
