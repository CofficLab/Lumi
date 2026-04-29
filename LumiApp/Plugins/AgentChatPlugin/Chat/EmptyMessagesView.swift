import SwiftUI

/// 空消息视图 - 已选择会话但没有消息时显示
struct EmptyMessagesView: View {
    @EnvironmentObject private var ConversationVM: ConversationVM
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        let theme = themeManager.activeAppTheme

        VStack(spacing: 20) {
            Spacer()

            // 图标
            Image(systemName: "text.bubble.fill")
                .font(.system(size: 56))
                .foregroundStyle(theme.workspaceTertiaryTextColor())

            // 标题
            Text(String(localized: "No Messages", table: "AgentMessages"))
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(theme.workspaceTextColor())

            // 描述
            Text(String(localized: "No Messages Description", table: "AgentMessages"))
                .font(.body)
                .foregroundStyle(theme.workspaceSecondaryTextColor())
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // 示例引导
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "For Example", table: "AgentMessages"))
                    .font(.caption)
                    .foregroundStyle(theme.workspaceTertiaryTextColor())

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Example Error Log", table: "AgentMessages"))
                        .font(.caption)
                        .foregroundStyle(theme.workspaceSecondaryTextColor())
                    Text(String(localized: "Example Test Plan", table: "AgentMessages"))
                        .font(.caption)
                        .foregroundStyle(theme.workspaceSecondaryTextColor())
                }
            }
            .padding(.horizontal, 40)

            QuickStartActionsView(sendStrategy: .sendInCurrentConversation)
            .padding(.horizontal, 40)

            // 当前对话 ID
            if let id = ConversationVM.selectedConversationId {
                Text(id.uuidString)
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundStyle(theme.workspaceTertiaryTextColor())
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

#Preview {
    EmptyMessagesView()
        .frame(width: 600, height: 400)
        .inRootView()
}