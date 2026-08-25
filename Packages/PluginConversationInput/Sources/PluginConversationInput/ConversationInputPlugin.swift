import KernelCore
import LumiUI
import os
import ProviderChatSection
import ProviderConversationInput
import ProviderMessageSender
import KitSuperLog
import SwiftUI

/// Conversation Input Plugin（KernelCore 版本）
///
/// 由旧版 `Plugins/ConversationInputPlugin`（KernelLumi / LumiPlugin 架构）复刻而来：
/// - `onBoot` 向 `ChatSectionProviding` 注册底部固定输入框（`ComposerView` +
///   原生 AppKit 编辑器 `ChatInputEditorView`，含 IME / 拖放 / 粘贴折叠预览），
///   并在 Action Bar 注册发送/停止按钮（`SendActionBarButton`）；
/// - 输入状态使用内核已注册的 `ConversationInputProviding`，发送使用
///   `MessageSendingProviding`，与「文件树 → 添加到对话」等消费方共享同一状态；
/// - `onShutdown` 撤回全部贡献。
///
/// 与旧版的对应关系：
/// - `registerConversationInputService(inputState)` → 内核 `ConversationInputProviding`
///   （FactoryLumi 已装配 `DefaultConversationInputProviding`）；
/// - `chatSectionItems(.bottomFixed)` → `ChatSectionProviding.addItems`；
/// - `chatSectionActionBarItems(.trailing)` → `ChatSectionProviding.addBarItems(.actionTrailing)`；
/// - `kernel.messageSender`（isSending/send/stop）→ `MessageSendingProviding`
///   （`isSending` / `sendMessage` / `cancelCurrentRequest`）。
///
/// 相比旧版移除：图片拖拽经 `messageSender.addAttachment` 作为附件发送——新版
/// `MessageSendingProviding` 无附件管道，图片文件与其他文件一样以路径文本插入输入框。
@MainActor
public final class ConversationInputPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.conversation-input", category: "ConversationInput")

    public let id = "com.coffic.lumi.plugin.conversation-input"
    public let order = 83
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.conversation-input",
        name: "Conversation Input",
        description: "",
        category: .chat,
        stage: .stable,
        policy: .alwaysOn
    )

    public init() {}

    public var name: String {
        LumiPluginLocalization.string("Conversation Input", bundle: .module)
    }


    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ChatSectionProviding from kernel")
            return
        }

        let input = kernel.resolveProvider((any ConversationInputProviding).self)
        let sender = kernel.resolveProvider((any MessageSendingProviding).self)

        // 1. 底部固定输入框
        chat.addItems([
            ChatSectionItem(
                id: id,
                order: 900,
                placement: .bottomFixed,
                fillsRemainingHeight: false,
                showsTrailingDivider: false
            ) {
                ConversationInputView(input: input, sender: sender)
            },
        ])

        // 2. Action Bar 发送/停止按钮
        chat.addBarItems([
            ChatSectionBarItem(
                id: "\(id).send-button",
                placement: .actionTrailing
            ) {
                SendActionBarButton(input: input, sender: sender)
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeItem(id: id)
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).send-button")
    }
}
