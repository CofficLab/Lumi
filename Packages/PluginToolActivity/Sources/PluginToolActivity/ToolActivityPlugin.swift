import KernelCore
import KitSuperLog
import os
import ProviderChatSection
import ProviderConversation
import ProviderToolManager
import SwiftUI

/// 在 ChatToolbar 展示当前对话工具活动的 UI 插件。
///
/// 工具执行与持久化仍由 PluginToolManager 负责；本插件只订阅
/// ToolManagerProviding 的公开快照和事件，并贡献一个 ChatSection bar item。
@MainActor
public final class ToolActivityPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.tool-activity",
        category: "ToolActivity"
    )

    public let id = "com.coffic.lumi.plugin.tool-activity"
    public let order = 87
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.tool-activity",
        name: "Tool Activity",
        description: "Shows tool calls for the current conversation.",
        category: .chat,
        stage: .stable,
        policy: .enabledByDefault
    )

    private var viewModel: ToolActivityViewModel?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.t)Missing ChatSection, Conversation, or ToolManager provider")
            return
        }

        viewModel = ToolActivityViewModel(
            conversations: conversations,
            toolManager: toolManager
        )

        chat.removeBarItem(id: "\(id).toolbar")
        chat.addBarItems([
            ChatSectionBarItem(
                id: "\(id).toolbar",
                order: order,
                placement: .toolbarTrailing
            ) { [weak self] in
                if let viewModel = self?.viewModel {
                    ToolActivityToolbarView(viewModel: viewModel)
                } else {
                    EmptyView()
                }
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).toolbar")
        viewModel?.cancel()
        viewModel = nil
    }
}
