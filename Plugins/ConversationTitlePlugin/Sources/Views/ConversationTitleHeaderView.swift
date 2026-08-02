import LumiKernel
import LumiUI
import SwiftUI

/// Header view displaying the current conversation title
struct ConversationTitleHeaderView: View {
    @ObservedObject var kernel: LumiKernel
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    var body: some View {
        Text(displayTitle)
            .font(.appMicroEmphasized)
            .foregroundColor(theme.textPrimary)
            .lineLimit(1)
    }

    private var displayTitle: String {
        guard let conversations = kernel.conversations,
              let conversationID = conversations.selectedConversationID,
              let conversation = conversations.conversations.first(where: { $0.id == conversationID }) else {
            return ""
        }
        return conversation.displayTitle
    }
}
