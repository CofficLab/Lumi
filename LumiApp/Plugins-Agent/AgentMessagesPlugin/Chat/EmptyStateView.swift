import SwiftUI

/// 空状态视图 - 未选择会话时显示
struct EmptyStateView: View {
    @EnvironmentObject private var ConversationVM: ConversationVM
    @EnvironmentObject private var conversationCreationVM: ConversationCreationVM

    private var hasAnyConversation: Bool {
        !ConversationVM.fetchAllConversations().isEmpty
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // 图标
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            // 标题
            Text(String(localized: hasAnyConversation ? "选择一个会话开始聊天" : "暂无对话", table: "AgentMessages"))
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            if hasAnyConversation {
                // 描述
                Text(String(localized: "从左侧列表选择一个现有会话，或创建新会话", table: "AgentMessages"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button("查看新手引导") {
                    NotificationCenter.default.post(
                        name: Notification.Name("AgentOnboarding.Show"),
                        object: nil
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.accent)
                .accessibilityLabel("查看新手引导")
                .accessibilityHint("打开首次使用说明")

                QuickStartActionsView(sendStrategy: .createConversationAndSend)
                    .padding(.top, 4)
            } else {
                Button {
                    Task {
                        await conversationCreationVM.createNewConversation()
                    }
                } label: {
                    Label("新建对话", systemImage: "plus.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("新建对话")
                .accessibilityHint("创建一个新的会话")

                Button("查看新手引导") {
                    NotificationCenter.default.post(
                        name: Notification.Name("AgentOnboarding.Show"),
                        object: nil
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.accent)
                .accessibilityLabel("查看新手引导")
                .accessibilityHint("打开首次使用说明")

                QuickStartActionsView(sendStrategy: .createConversationAndSend)
                    .padding(.top, 4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("空状态页面")
    }
}

#Preview {
    EmptyStateView()
        .frame(width: 600, height: 400)
        .inRootView()
}