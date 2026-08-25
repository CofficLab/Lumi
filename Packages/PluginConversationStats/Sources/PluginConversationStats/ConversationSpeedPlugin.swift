import os
import KernelCore
import ProviderChatSection
import ProviderConversation
import ProviderMessage
import KitSuperLog
import SwiftUI

/// 会话流式速度插件
///
/// 在 Chat 工具栏显示当前对话的输出速度（tokens/s）。
///
/// 复刻自旧版 `Plugins/ConversationSpeedPlugin`：
/// - 从 `MessageManaging.messages(for:)` 获取消息列表
/// - 从 assistant 消息的 `outputTokenCount` / `streamingDurationMs` 计算速度
/// - 展示折线图趋势和详细指标
@MainActor
public final class ConversationSpeedPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.conversation-speed", category: "ConversationSpeed")

    public let id = "com.coffic.lumi.plugin.conversation-speed"
    public let order = 86
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.conversation-speed",
        name: "Conversation Speed",
        description: "",
        category: .chat,
        stage: .stable,
        policy: .alwaysOn
    )

    public init() {}


    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self),
              let messages = kernel.resolveProvider((any MessageManaging).self) else {
            Self.logger.error("\(Self.t)Failed to resolve required providers")
            return
        }

        chat.addBarItems([
            ChatSectionBarItem(
                id: "\(id).toolbar-button",
                order: 86,
                placement: .toolbarLeading
            ) {
                SpeedToolbarView(
                    conversations: conversations,
                    messages: messages
                )
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).toolbar-button")
    }
}
