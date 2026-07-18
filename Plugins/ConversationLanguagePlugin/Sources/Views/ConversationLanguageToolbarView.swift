import LumiCoreKit
import LumiCoreKit
import SwiftUI

struct ConversationLanguageToolbarView: View {
    @ObservedObject private var chatService: ChatService

    init(chatService: any LumiChatServicing) {
        guard let chatService = chatService as? ChatService else {
            preconditionFailure("ConversationLanguageToolbarView requires ChatService")
        }
        _chatService = ObservedObject(wrappedValue: chatService)
    }

    var body: some View {
        LanguageToggleButton(chatService: chatService)
    }
}
