import SwiftUI

/// 历史对话卡片视图
///
/// 以卡片形式展示单个历史对话，包含标题、项目、消息数、供应商/模型、时间等信息。
struct HistoryConversationCardView: View {
    let row: HistoryConversationRow

    var body: some View {
        HStack(spacing: 10) {
            // 左侧图标
            Image(systemName: "message.fill")
                .font(.system(size: 14))
                .foregroundColor(.accentColor)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // 中间内容
            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 6) {
                    if row.projectId != "-" {
                        Label {
                            Text(row.projectId)
                                .font(.system(size: 10))
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: "folder")
                                .font(.system(size: 8))
                        }
                        .foregroundColor(.secondary)
                    }

                    if let providerId = row.providerId {
                        Label {
                            Text(providerId)
                                .font(.system(size: 10))
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: "server.rack")
                                .font(.system(size: 8))
                        }
                        .foregroundColor(.secondary)
                    }

                    if let model = row.model {
                        Label {
                            Text(model)
                                .font(.system(size: 10))
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: "cpu")
                                .font(.system(size: 8))
                        }
                        .foregroundColor(.secondary)
                    }

                    Label {
                        Text("\(row.messageCount)")
                            .font(.system(size: 10))
                    } icon: {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 右侧时间
            VStack(alignment: .trailing, spacing: 2) {
                Text(row.updatedAt, style: .date)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(row.updatedAt, style: .time)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview("History Conversation Card") {
    HistoryConversationCardView(
        row: HistoryConversationRow(
            id: UUID(),
            title: "帮我重构 ViewModel 层",
            projectId: "Lumi",
            createdAt: Date().addingTimeInterval(-3600),
            updatedAt: Date().addingTimeInterval(-300),
            messageCount: 12,
            providerId: "openai",
            model: "gpt-4o"
        )
    )
    .frame(width: 400)
    .padding()
}
