import MagicKit
import SwiftUI

/// 新会话按钮视图组件
struct NewChatButton: View {
    @EnvironmentObject var conversationCreationVM: ConversationCreationVM

    private let iconSize: CGFloat = 14
    private let iconButtonSize: CGFloat = 28

    enum Style {
        case iconOnly
        case cta
    }

    var style: Style = .iconOnly

    var body: some View {
        Button {
            Task {
                await conversationCreationVM.createNewConversation()
            }
        } label: {
            switch style {
            case .iconOnly:
                Image(systemName: "plus.circle")
                    .font(.system(size: iconSize))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                    .frame(width: iconButtonSize, height: iconButtonSize)
                    .background(Color.black.opacity(0.05))
                    .clipShape(Circle())
            case .cta:
                Label(String(localized: "New Chat", table: "AgentNewChat"), systemImage: "plus.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .buttonStyle(.plain)
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

#Preview("New Chat Button - Large") {
    NewChatButton(style: .cta)
        .padding()
        .background(Color.black)
        .inRootView()
        .frame(width: 1200, height: 1200)
}