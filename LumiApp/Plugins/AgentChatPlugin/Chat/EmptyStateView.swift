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

                    Text(String(localized: hasAnyConversation ? "Select Conversation" : "No Conversations", table: "AgentMessages"))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    if hasAnyConversation {
                        Text(String(localized: "Select or Create Conversation", table: "AgentMessages"))
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if !hasAnyConversation {
                        AppButton(String(localized: "New Conversation", table: "AgentMessages"), systemImage: "plus.circle.fill", style: .primary) {
                            Task {
                                await conversationCreationVM.createNewConversation()
                            }
                        }
                        .accessibilityLabel(String(localized: "New Conversation", table: "AgentMessages"))
                        .accessibilityHint(String(localized: "New Conversation Hint", table: "AgentMessages"))
                    }

                    AppButton(String(localized: "Onboarding Guide", table: "AgentMessages"), style: .ghost, size: .small) {
                        NotificationCenter.default.post(
                            name: Notification.Name("AgentOnboarding.Show"),
                            object: nil
                        )
                    }
                    .accessibilityLabel(String(localized: "Onboarding Guide", table: "AgentMessages"))
                    .accessibilityHint(String(localized: "Onboarding Guide Hint", table: "AgentMessages"))

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
        .accessibilityLabel(String(localized: "Empty State Page", table: "AgentMessages"))
    }
}

#Preview {
    EmptyStateView()
        .frame(width: 600, height: 400)
        .inRootView()
}
