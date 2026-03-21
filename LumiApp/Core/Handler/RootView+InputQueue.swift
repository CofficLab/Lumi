import Foundation
import MagicKit

extension RootView {
    @MainActor
    func onInputQueueRequested() {
        guard let requestId = container.inputQueueVM.pendingRequest?.id else { return }
        guard let request = container.inputQueueVM.consumePendingRequest(id: requestId) else { return }

        guard container.conversationVM.selectedConversationId != nil else {
            if Self.verbose {
                AppLogger.core.info("\(Self.t) No conversation selected")
            }
            return
        }

        let pendingImages = container.agentAttachmentsVM.drainPendingImageAttachments()
        let allImages = request.images + pendingImages
        guard !request.text.isEmpty || !allImages.isEmpty else { return }

        let message = ChatMessage(role: .user, content: request.text, images: allImages)
        container.messageSenderVM.enqueueMessage(message)
    }
}
