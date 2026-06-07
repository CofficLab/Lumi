import LumiCoreKit
import SwiftUI

struct ConversationTitleEventObserver<Content: View>: View {
    let content: Content

    var body: some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .messageSaved)) { notification in
                guard let message = notification.object as? ChatMessage,
                      let conversationId = notification.userInfo?["conversationId"] as? UUID else {
                    return
                }
                TitleOrchestrator.handleMessageSaved(message: message, conversationId: conversationId)
            }
    }
}
