import LumiChatKit
import LumiCoreKit
import LumiUI
import SwiftUI

struct ConversationRailPanelView: View {
    @StateObject private var context: ConversationListContext

    init(chatService: ChatService, projectPathStore: LumiCurrentProjectPathStoring?) {
        _context = StateObject(
            wrappedValue: ConversationListContext(
                chatService: chatService,
                projectPathStore: projectPathStore
            )
        )
    }

    var body: some View {
        ConversationListView(context: context)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .appSurface(style: .panel, cornerRadius: 0)
    }
}
