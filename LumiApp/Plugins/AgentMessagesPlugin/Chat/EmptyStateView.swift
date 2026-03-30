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

            AppCard(style: .elevated, padding: EdgeInsets(top: 24, leading: 28, bottom: 24, trailing: 28)) {
                VStack(spacing: 14) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)

                    Text(String(localized: hasAnyConversation ? "选择一个会话开始聊天" : "暂无对话", table: "AgentMessages"))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    if hasAnyConversation {
                        Text(String(localized: "从左侧列表选择一个现有会话，或创建新会话", table: "AgentMessages"))
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if !hasAnyConversation {
                        AppButton("新建对话", systemImage: "plus.circle.fill", style: .primary) {
                            Task {
                                await conversationCreationVM.createNewConversation()
                            }
                        }
                        .accessibilityLabel("新建对话")
                        .accessibilityHint("创建一个新的会话")
                    }

                    AppButton("查看新手引导", style: .ghost, size: .small) {
                        NotificationCenter.default.post(
                            name: Notification.Name("AgentOnboarding.Show"),
                            object: nil
                        )
                    }
                    .accessibilityLabel("查看新手引导")
                    .accessibilityHint("打开首次使用说明")

                    QuickStartActionsView(sendStrategy: .createConversationAndSend)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 28)

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
