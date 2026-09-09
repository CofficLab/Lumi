import Foundation
import KernelCore
import KitSuperLog
import os
import ProviderAgentLoop
import ProviderChatSection
import ProviderConversation
import ProviderMessageRendering
import ProviderToolManager
import KitAgentTool
import LumiUI
import SwiftUI

/// AskUser 插件：注册 `ask_user` 工具，让 LLM 可向用户提问并等待回答。
/// - 注册 `AskUserTool` 到 `ToolManagerProviding`；
/// - 工具 `executeResult` 返回 `awaitingUserResponse: true`，AgentLoop 检测后
///   创建 suspension（kind = "userInput"）并暂停回合；
/// - 用户回答后经 `AgentLoopProviding.resumeTurn(in:request:)` 恢复。
///
/// V1 通过聊天区固定项直接展示当前挂起的问题；V2/V3 继续由工具调用行渲染器
/// 展示。两条路径共用 `AskUserPendingView` 和 `AskUserBridge`。
@MainActor
public final class AskUserPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.ask-user", category: "AskUser")

    public let id = "com.coffic.lumi.plugin.ask-user"
    public let order = 88
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.ask-user",
        name: "Ask User",
        description: "",
        category: .general,
        stage: .stable,
        policy: .alwaysOn
    )

    private var chatViewModel: AskUserChatViewModel?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        AskUserBridge.shared.start(kernel: kernel)
        guard let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ConversationManaging, ToolManagerProviding from kernel")
            return
        }
        toolManager.add(AskUserTool(conversations: conversations), pluginID: id)
        kernel.resolveProvider((any ToolCallRenderingProviding).self)?
            .register(AskUserRowRenderer())

        if let agentLoop = kernel.resolveProvider((any AgentLoopProviding).self),
           let chat = kernel.resolveProvider((any ChatSectionProviding).self) {
            let viewModel = AskUserChatViewModel(
                conversations: conversations,
                agentLoop: agentLoop
            )
            chatViewModel = viewModel
            chat.addItems([
                ChatSectionItem(
                    id: "\(id).pending-question",
                    order: 90,
                    placement: .bottomFixed,
                    showsTrailingDivider: false
                ) { [viewModel] in
                    AskUserChatSectionView(viewModel: viewModel)
                }
            ])
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeItem(id: "\(id).pending-question")
        chatViewModel?.cancel()
        chatViewModel = nil
        kernel.resolveProvider((any ToolManagerProviding).self)?
            .remove(id: AskUserTool.toolName)
        kernel.resolveProvider((any ToolCallRenderingProviding).self)?
            .unregister(id: AskUserRowRenderer.id)
    }
}
