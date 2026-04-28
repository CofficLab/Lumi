import MagicKit
import SwiftUI

/// 新会话按钮视图组件
struct NewChatButton: View {
    @EnvironmentObject var conversationCreationVM: ConversationCreationVM
    @EnvironmentObject private var themeManager: ThemeManager

    private let iconSize: CGFloat = 14
    private let iconButtonSize: CGFloat = 28

    var body: some View {
        let theme = themeManager.activeAppTheme

        Button {
            Task {
                await conversationCreationVM.createNewConversation()
            }
        } label: {
            Image(systemName: "plus.circle")
                .font(.system(size: iconSize))
                .foregroundColor(theme.workspaceSecondaryTextColor())
                .frame(width: iconButtonSize, height: iconButtonSize)
                .clipShape(Circle())
        }
        .help(String(localized: "Start New Conversation", table: "AgentNewChat"))
    }
}

#Preview("New Chat Button - Small") {
    NewChatButton()
        .padding()
        .background(Color.black)
        .inRootView()
        .frame(width: 800, height: 600)
}

