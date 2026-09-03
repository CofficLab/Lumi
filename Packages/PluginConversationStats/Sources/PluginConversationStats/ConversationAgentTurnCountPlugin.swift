import os
import KernelCore
import ProviderAgentLoop
import ProviderChatSection
import ProviderConversation
import KitSuperLog
import SwiftUI

/// Agent Turn 运行状态插件
///
/// 在 Chat 工具栏显示当前对话是否正在运行 Agent Turn。
///
/// 复刻自旧版 `Plugins/ConversationAgentTurnCountPlugin`：
/// - 通过 `AgentLoopProviding.isRunning(for:)` 检测运行状态
/// - 运行中时显示脉冲动画指示器，空闲时隐藏
@MainActor
public final class ConversationAgentTurnCountPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.conversation-agent-turn-count", category: "ConversationAgentTurnCount")

    public let id = "com.coffic.lumi.plugin.conversation-agent-turn-count"
    public let order = 87
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.conversation-agent-turn-count",
        name: "Conversation Agent Turn Count",
        description: "",
        category: .chat,
        stage: .stable,
        policy: .alwaysOn
    )

    private let toolbarState = AgentTurnStatusToolbarState()
    private var observer: AgentTurnStatusObserver?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let agentLoop = kernel.resolveProvider((any AgentLoopProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve required providers")
            return
        }

        observer?.cancel()
        observer = AgentTurnStatusObserver(
            conversations: conversations,
            agentLoop: agentLoop,
            onConversationChange: { [weak toolbarState] newID in
                toolbarState?.selectedConversationID = newID
                toolbarState?.revision &+= 1
            },
            onAgentLoopChange: { [weak toolbarState] conversationID in
                guard conversationID == toolbarState?.selectedConversationID else { return }
                toolbarState?.revision &+= 1
            }
        )

        chat.addBarItems([
            ChatSectionBarItem(
                id: "\(id).toolbar-button",
                order: 87,
                placement: .toolbarLeading
            ) {
                AgentTurnStatusToolbarView(
                    agentLoop: agentLoop,
                    state: self.toolbarState
                )
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        observer?.cancel()
        observer = nil
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).toolbar-button")
    }
}

@MainActor
final class AgentTurnStatusToolbarState: ObservableObject {
    @Published var selectedConversationID: UUID?
    @Published var revision = 0
}
