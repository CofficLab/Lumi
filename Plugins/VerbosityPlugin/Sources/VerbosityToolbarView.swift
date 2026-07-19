import LumiKernel
import LumiKernel
import SwiftUI

struct VerbosityToolbarView: View {
    @ObservedObject private var chatService: ChatService

    init(chatService: any LumiChatServicing) {
        guard let chatService = chatService as? ChatService else {
            preconditionFailure("VerbosityToolbarView requires ChatService")
        }
        _chatService = ObservedObject(wrappedValue: chatService)
    }

    var body: some View {
        VerbosityPicker(chatService: chatService)
    }
}
