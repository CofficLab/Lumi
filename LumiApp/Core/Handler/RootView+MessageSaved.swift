import Foundation
import MagicKit
import SwiftUI

extension RootView {
    func onMessageSaved(_ message: ChatMessage, conversationId: UUID) {
        guard message.role == .assistant else { return }

        if message.hasToolCalls {
            Task {
                await continueSendAfterAssistantWithToolCalls(
                    assistantMessage: message,
                    conversationId: conversationId
                )
            }
        }
    }
}
