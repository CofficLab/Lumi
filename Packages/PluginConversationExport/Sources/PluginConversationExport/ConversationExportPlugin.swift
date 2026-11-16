import KernelCore
import LumiLoggingKit
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
        description: "Export the current conversation as a self-contained HTML file, with debugging and sharing presets.",
        category: .chat,
        stage: .stable,
        policy: .enabledByDefault
    )

    private var viewModel: ConversationExportViewModel?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        installExportEntry(kernel: kernel)
    }

    /// 运行时重新启用：恢复导出入口。
    ///
    /// 走这条路径说明插件曾经 Boot 过、入口已被撤回，这里重新登记一次即可。
    public func onEnable(kernel: KernelCoreContainer) async throws {
        installExportEntry(kernel: kernel)
    }

    /// 运行时禁用：立即撤回导出入口并停掉 ViewModel。
    ///
    /// 内核在运行时禁用插件时只撤回它**显式登记**的贡献，不会替插件清理
    /// Provider 侧的写入。导出按钮是通过 `chat.addBarItems` 直接写进
    /// ChatSection 的，不带内核贡献归属；若不在这里 `removeBarItem`，插件在
    /// 设置里显示「已禁用」后，导出按钮仍在工具栏上，且 ViewModel 仍能快照、
    /// 生成并打开导出文件（#797）。
    public func onDisable(kernel: KernelCoreContainer) async throws {
        removeExportEntry(kernel: kernel)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        removeExportEntry(kernel: kernel)
    }

    private func installExportEntry(kernel: KernelCoreContainer) {
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

    private func removeExportEntry(kernel: KernelCoreContainer) {
        viewModel?.cancel()
        viewModel = nil
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).toolbar")
    }
}
