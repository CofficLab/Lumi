import Foundation
import ProviderConversationInput
import ProviderMessage
import ProviderMessageSender

/// 文件附件按钮需要的最小能力边界。
///
/// View 不再直接持有 `KernelCoreContainer` 解析 Provider，只面向本协议编程；
/// Provider 的解析与适配在插件入口完成。
@MainActor
protocol ChatFileAttachmentCapability: AnyObject {
    /// 把附件追加到当前会话的待发送内容。
    func addFileAttachment(_ attachment: UserFileAttachment)

    /// 读取附件失败时，把错误写入输入区展示。
    func presentLoadError(_ message: String)
}

/// 将内核的消息发送与输入区能力收窄为附件按钮所需的能力。
@MainActor
final class ChatFileAttachmentCapabilityAdapter: ChatFileAttachmentCapability {
    private let sender: (any MessageSendingProviding)?
    private let conversationInput: (any ConversationInputProviding)?

    init(
        sender: (any MessageSendingProviding)?,
        conversationInput: (any ConversationInputProviding)?
    ) {
        self.sender = sender
        self.conversationInput = conversationInput
    }

    func addFileAttachment(_ attachment: UserFileAttachment) {
        sender?.addFileAttachment(attachment)
    }

    func presentLoadError(_ message: String) {
        conversationInput?.errorMessage = message
    }
}
