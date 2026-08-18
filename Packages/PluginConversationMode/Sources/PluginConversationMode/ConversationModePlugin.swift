import Foundation
import KernelCore
import os
import ProviderChatSection
import ProviderConversation
import SuperLogKit
import SwiftUI

/// 会话行为控制插件：自动化级别切换（对话 / 构建 / 自主）。
///
/// 复刻自旧版 `Plugins/ConversationModePlugin`：
/// - 在 Chat 分区工具栏注册自动化级别 chip（`ChatSectionBarPlacement.toolbarLeading`）；
/// - 点击弹出三档选择（chat / build / autonomous），写入 `ConversationManaging`；
/// - AgentLoop 每轮请求读取 `automationLevel` 决定是否附带工具、是否需批准。
///
/// 与旧版的对应关系：
/// - `chatSectionToolbarBarItems` → `ChatSectionProviding.addBarItems(.toolbarLeading)`；
/// - `kernel.conversations` → 内核 `ConversationManaging`（FactoryLumi2 已装配，
///   且 PluginConversationManager order=7 可能已替换为持久化实现）。
@MainActor
public final class ConversationModePlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.conversation-mode", category: "ConversationMode")

    /// 保持旧版插件 ID，插件启用状态 / 存储 / 自动化不失效。
    public let id = "com.coffic.lumi.plugin.conversation-mode"
    public let order = 84

    public init() {}

    public var metadata: PluginMetadata {
        PluginMetadata(
            id: id,
            name: "Conversation Mode",
            description: "Automation level switch (chat / build / autonomous)",
            category: .chat,
            stage: .preview,
            policy: .alwaysOn
        )
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self),
              let conversations = kernel.resolveProvider((any ConversationManaging).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ChatSectionProviding, ConversationManaging from kernel")
            return
        }

        chat.addBarItems([
            ChatSectionBarItem(
                id: "\(id).toolbar-button",
                order: 84,
                placement: .toolbarTrailing
            ) {
                AutomationLevelToolbarView(conversations: conversations)
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).toolbar-button")
    }
}
