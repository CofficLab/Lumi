import Foundation
import KernelCore
import LumiLoggingKit
import os
import ProviderChatSection
import ProviderConversation
import ProviderMessage
import SwiftUI

/// 会话 token 用量插件。
///
/// 在 Chat header 栏右侧显示当前对话的**总** token 数；点击后弹出 popover
/// 展示输入 / 输出拆分。
///
/// - 数据来源：`MessageManaging` 里的 assistant 消息上报的用量字段；
/// - 刷新时机：选中会话变化、消息插入 / 更新 / 删除；
/// - 与「上下文用量」插件的区别：这里统计的是**已消耗**的累计用量，
///   而上下文用量展示的是当前窗口占用比例。
@MainActor
public final class ConversationTokenUsagePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.conversation-token-usage",
        category: "ConversationTokenUsage"
    )

    public let id = "com.coffic.lumi.plugin.conversation-token-usage"
    public let order = 93
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.conversation-token-usage",
        name: "Conversation Token Usage",
        description: "Show total token usage of the current conversation in the chat header",
        category: .chat,
        stage: .stable,
        policy: .alwaysOn
    )

    /// header 栏状态。
    ///
    /// 保持 internal 以便单元测试直接断言「Provider 事件 → header 状态」的
    /// 转发链路，对外仍不暴露任何 API。
    let toolbarState = TokenUsageToolbarState()
    private var observer: TokenUsageObserver?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let messages = kernel.resolveProvider((any MessageManaging).self) else {
            Self.logger.error("\(Self.t)Failed to resolve required providers")
            return
        }

        observer?.cancel()
        observer = TokenUsageObserver(
            conversations: conversations,
            messages: messages,
            onConversationChange: { [weak toolbarState] newID in
                toolbarState?.setSelectedConversationID(newID)
            },
            onMessageChange: { [weak toolbarState] conversationID in
                guard conversationID == toolbarState?.selectedConversationID else { return }
                toolbarState?.markMessagesChanged(conversationID: conversationID)
            }
        )

        chat.addBarItems([
            ChatSectionBarItem(
                id: "\(id).header",
                order: order,
                placement: .headerTrailing
            ) {
                TokenUsageHeaderView(
                    messages: messages,
                    state: self.toolbarState
                )
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        observer?.cancel()
        observer = nil
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).header")
    }
}
