import LumiChatKit
import LumiCoreKit
import LumiUI
import SwiftUI

struct ConversationRailPanelView: View {
    @LumiTheme private var theme
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
        VStack(spacing: 0) {
            header
            GlassDivider(thickness: 1, opacity: 0.12)
            ConversationListView(context: context)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .appSurface(style: .panel, cornerRadius: 0)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(String(localized: "Chats", bundle: .module))
                .font(.appSectionTitle)
                .foregroundColor(theme.textPrimary)

            Spacer()

            AppIconButton(systemImage: "plus", size: .regular) {
                _ = context.createConversation()
            }
            .help(String(localized: "New Chat", bundle: .module))
        }
        .padding(12)
    }
}
