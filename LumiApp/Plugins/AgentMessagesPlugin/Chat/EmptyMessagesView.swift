import SwiftUI

/// 空消息视图 - 已选择会话但没有消息时显示
struct EmptyMessagesView: View {
    @EnvironmentObject private var ConversationVM: ConversationVM

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // 图标
            Image(systemName: "text.bubble.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)

            // 标题
            Text(String(localized: "暂无消息", table: "AgentMessages"))
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            // 描述
            Text(String(localized: "在下方输入框中输入您的问题，开始与 AI 助手对话", table: "AgentMessages"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // 示例引导
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "例如：", table: "AgentMessages"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "· 帮我解释这段错误日志", table: "AgentMessages"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "· 帮我为这个项目设计一个测试计划", table: "AgentMessages"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                    .foregroundStyle(.tertiary)
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