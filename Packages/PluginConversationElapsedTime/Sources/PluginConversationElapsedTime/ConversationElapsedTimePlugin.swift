import Foundation
import KernelCore
import LumiLoggingKit
import os
import ProviderChatSection
import ProviderConversation
import ProviderMessage
import SwiftUI

/// 会话模型用时插件。
///
/// 在 Chat header 栏右侧显示当前对话的**总**模型工作时间；点击后弹出 popover
/// 展示等待首 token / 生成时长的拆分。
///
/// - 数据来源：assistant 消息上报的 `latencyMs`（一次模型请求的端到端耗时）；
/// - 口径：只累加模型真正在推理的时间，用户空闲等待不计入；
/// - 刷新时机：选中会话变化、消息插入 / 更新 / 删除。
@MainActor
public final class ConversationElapsedTimePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.conversation-elapsed-time",
        category: "ConversationElapsedTime"
    )

    public let id = "com.coffic.lumi.plugin.conversation-elapsed-time"
    /// 紧挨着 token 用量（order 93）显示。
    public let order = 92
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.conversation-elapsed-time",
        name: "Conversation Elapsed Time",
        description: "Show total LLM working time of the current conversation in the chat header",
        category: .chat,
        stage: .stable,
        policy: .alwaysOn
    )

    /// header 栏状态。
    ///
    /// 保持 internal 以便单元测试直接断言「Provider 事件 → header 状态」的
    /// 转发链路，对外仍不暴露任何 API。
    let toolbarState = ElapsedTimeToolbarState()
    private var observer: ElapsedTimeObserver?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let messages = kernel.resolveProvider((any MessageManaging).self) else {
            Self.logger.error("\(Self.t)Failed to resolve required providers")
            return
        }

        observer?.cancel()
        observer = ElapsedTimeObserver(
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
                ElapsedTimeHeaderView(
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
