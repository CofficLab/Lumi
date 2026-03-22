import SwiftUI

extension RootView {
    func upsertRootSystemMessage(_ content: String) {
        let currentMessages = container.messageViewModel.messages
        let systemMessage = ChatMessage(role: .system, content: content)

        if !currentMessages.isEmpty, currentMessages[0].role == .system {
            container.messageViewModel.updateMessage(systemMessage, at: 0)
        } else {
            container.messageViewModel.insertMessage(systemMessage, at: 0)
        }
    }
}
