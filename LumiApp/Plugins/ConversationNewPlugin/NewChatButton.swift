import SwiftUI
import LumiUI

/// 新会话按钮视图组件
struct NewChatButton: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @EnvironmentObject var conversationVM: WindowConversationVM

    private let iconButtonSize: CGFloat = 28

    var body: some View {
        Button {
            Task {
                await conversationVM.createNewConversation()
            }
        } label: {
            Image(systemName: "plus")
                .font(.appCallout)
                .foregroundColor(theme.textSecondary)
                .frame(width: iconButtonSize, height: iconButtonSize)
                .clipShape(Circle())
        }
        .help(String(localized: "Start New Conversation", table: "ConversationNew"))
    }
}

#Preview("New Chat Button - Small") {
    NewChatButton()
        .padding()
        .background(Color.black)
        .inRootView()
        .frame(width: 800, height: 600)
}
