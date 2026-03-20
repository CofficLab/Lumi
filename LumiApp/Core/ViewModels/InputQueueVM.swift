import Foundation
import MagicKit

/// 负责把用户输入（文本 + 附件）入队到 `MessageSenderVM`。
@MainActor
final class InputQueueVM: ObservableObject, SuperLog {
    nonisolated static var emoji: String { "🔄" }
    nonisolated static var verbose: Bool { false }

    private let conversationVM: ConversationVM
    private let messageSenderVM: MessageQueueVM
    private let attachmentsVM: AttachmentsVM

    init(
        conversationVM: ConversationVM,
        messageSenderVM: MessageQueueVM,
        attachmentsVM: AttachmentsVM
    ) {
        self.conversationVM = conversationVM
        self.messageSenderVM = messageSenderVM
        self.attachmentsVM = attachmentsVM
    }

    /// 将输入内容入队；只负责入队与清空附件，不做 slash/生成等执行动作。
    func enqueueText(_ text: String, images: [ImageAttachment] = []) {
        if Self.verbose {
            AppLogger.core.info("\(self.t) Enqueuing text: \(text)")
        }
        guard conversationVM.selectedConversationId != nil else {
            if Self.verbose {
                AppLogger.core.info("\(self.t) No conversation selected")
            }
            return
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let pendingImages = attachmentsVM.drainPendingImageAttachments()
        let allImages = images + pendingImages

        guard !trimmed.isEmpty || !allImages.isEmpty else { return }

        let message = ChatMessage(role: .user, content: trimmed, images: allImages)
        messageSenderVM.enqueueMessage(message)
    }
}

