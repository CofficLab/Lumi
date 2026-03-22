import Foundation
import MagicKit
import SwiftUI

extension RootView {
    func onMessageSaved(_ message: ChatMessage, conversationId: UUID) {
        if message.hasToolCalls {
            Task {
                await continueSendAfterToolCalls(
                    assistantMessage: message,
                    conversationId: conversationId
                )
            }
        }
    }
}
