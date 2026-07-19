import SwiftUI
import LumiUI
import LumiKernel

/// 历史对话卡片视图
///
/// 以卡片形式展示单个历史对话，包含标题、项目、消息数、供应商/模型、时间等信息。
public struct ConversationCardView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let row: HistoryConversationRow

    public var body: some View {
        HStack(spacing: 10) {
            // 左侧图标
            Image(systemName: "message.fill")
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.primary)
                .frame(width: 28, height: 28)
                .background(theme.primary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // 中间内容
            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.appCaptionEmphasized)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 6) {
                    if let chatModeRaw = row.chatMode {
                        Label {
                            Text(chatModeRaw)
                                .font(.appMicro)
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.appMicro)
                        }
                        .foregroundColor(theme.textSecondary)
                    }

                    if row.projectId != "-" {
                        Label {
                            Text(row.projectId)
                                .font(.appMicro)
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: "folder")
                                .font(.appMicro)
                        }
                        .foregroundColor(theme.textSecondary)
                    }

                    if let providerId = row.providerId {
                        Label {
                            Text(providerId)
                                .font(.appMicro)
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: "server.rack")
                                .font(.appMicro)
                        }
                        .foregroundColor(theme.textSecondary)
                    }

                    if let model = row.model {
                        Label {
                            Text(model)
                                .font(.appMicro)
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: "cpu")
                                .font(.appMicro)
                        }
                        .foregroundColor(theme.textSecondary)
                    }

                    Label {
                        Text("\(row.messageCount)")
                            .font(.appMicro)
                    } icon: {
                        Image(systemName: "text.bubble")
                            .font(.appMicro)
                    }
                    .foregroundColor(theme.textSecondary)
                }
            }

            Spacer()

            // 右侧时间
            VStack(alignment: .trailing, spacing: 2) {
                Text(row.updatedAt, style: .date)
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
                Text(row.updatedAt, style: .time)
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .appSurface(style: .subtle, cornerRadius: 8)
    }
}

// MARK: - Preview

#Preview("History Conversation Card") {
    ConversationCardView(
        row: HistoryConversationRow(
            id: UUID(),
            title: "帮我重构 ViewModel 层",
            projectId: "Lumi",
            createdAt: Date().addingTimeInterval(-3600),
            updatedAt: Date().addingTimeInterval(-300),
            messageCount: 12,
            providerId: "openai",
            model: "gpt-4o",
            chatMode: "build"
        )
    )
    .frame(width: 400)
    .padding()
}
