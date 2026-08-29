import os
import KernelCore
import ProviderChatSection
import KitSuperLog

/// Chat File Attachment Plugin（KernelCore 版本）
///
/// 由旧版 `Plugins/ChatFileAttachmentPlugin`（KernelLumi / LumiPlugin 架构）复刻而来：
/// - 在 Chat 分区 Action Bar 的 leading 位置注册「添加文件」按钮（📎，回形针图标），
///   位于截图按钮右侧；
/// - 点击弹出文件选择器（`.fileImporter`），用户选择任意文件后经
///   `ConversationInputProviding.addToConversation(fileURLs:)` 把文件路径文本
///   插入输入框（当前文件选择器行为）。聊天输入框中的图片拖放由
///   `PluginConversationInput` 负责加入 `MessageSendingProviding` 的图片挂起池。
///
/// 与旧版的对应关系：
/// - `chatSectionActionBarItems(.leading)` → `ChatSectionProviding.addBarItems(.actionLeading)`；
/// - 文件选择器的 `kernel.messageSender.addAttachment / addFileAttachment` →
///   `ConversationInputProviding.addToConversation(fileURLs:)`；
/// - 图片拖放的附件管线保留在 `PluginConversationInput`，复用当前发送器接口。
@MainActor
public final class ChatFileAttachmentPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.chat-file-attachment", category: "ChatFileAttachment")

    /// 保持旧版插件 ID，插件启用状态 / 存储 / 自动化不失效。
    public let id = "com.coffic.lumi.plugin.chat-file-attachment"
    public let order = 81
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.chat-file-attachment",
        name: "Chat File Attachment",
        description: "",
        category: .chat,
        stage: .stable,
        policy: .alwaysOn
    )

    public init() {}

    public var name: String {
        LumiPluginLocalization.string("Chat File Attachment", bundle: .module)
    }


    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let chat = kernel.resolveProvider((any ChatSectionProviding).self) else {
            Self.logger.error("\(Self.t)Failed to resolve ChatSectionProviding from kernel\(self.r("chat is nil"))")
            return
        }

        // Action Bar 附件按钮（沿用旧版 chatSectionActionBarItems .leading，
        // order 82 排在截图按钮（81）之后）。
        chat.addBarItems([
            ChatSectionBarItem(
                id: "\(id).button",
                order: 82,
                placement: .actionLeading
            ) {
                ChatFileAttachmentButton(kernel: kernel)
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ChatSectionProviding).self)?
            .removeBarItem(id: "\(id).button")
    }
}
