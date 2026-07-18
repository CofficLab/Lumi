import LumiCoreKit
import LumiCoreKit
import SwiftUI

struct AutomationLevelToolbarView: View {
    @ObservedObject private var chatService: ChatService

    init(chatService: any LumiChatServicing) {
        guard let chatService = chatService as? ChatService else {
            preconditionFailure("AutomationLevelToolbarView requires ChatService")
        }
        _chatService = ObservedObject(wrappedValue: chatService)
    }

    var body: some View {
        AutomationLevelPicker(chatService: chatService)
    }
}
