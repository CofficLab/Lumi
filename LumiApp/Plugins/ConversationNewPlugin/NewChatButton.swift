import SwiftUI
import LumiUI

/// 新会话按钮视图组件
struct NewChatButton: View {
    @EnvironmentObject var conversationVM: WindowConversationVM

    var body: some View {
        AppIconButton(
            systemImage: "plus",
            label: String(localized: "Start New Conversation", table: "ConversationNew")
        ) {
            Task {
                await conversationVM.createNewConversation()
            }
        }
    }
}

#Preview("New Chat Button - Small") {
    NewChatButton()
        .padding()
        .background(Color.black)
        .inRootView()
        .frame(width: 800, height: 600)
}
