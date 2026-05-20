import SwiftUI
import LumiUI

// MARK: - Status Message
//
/// 负责渲染状态类消息（如"等待响应…"、"生成中…"），统一样式
struct StatusMessage: View {
    let message: ChatMessage

    var body: some View {
        if message.content == ChatMessage.turnCompletedSystemContentKey {
            // 对话轮次结束的专用视图
            TurnCompletedDivider(message: message)
        } else if let snapshot = ToolExecutionStatusSnapshot.parse(from: message.content) {
            ToolExecutionStatusCardView(
                snapshot: snapshot,
                conversationId: message.conversationId
            )
                .messageBubbleStyle(role: message.role, isError: message.isError)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                header

                PlainTextMessageContentView(
                    content: message.content,
                    monospaced: false
                )
                .font(.system(size: 12, weight: .regular))
                .messageBubbleStyle(role: message.role, isError: message.isError)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        MessageHeaderView {
            HStack(alignment: .center, spacing: 6) {
                AvatarView.status
                AppIdentityRow(title: "Status")
            }
        } trailing: {
            AppIdentityRow(
                title: formatTimestamp(message.timestamp),
                titleColor: Color.adaptive(light: "6B6B7B", dark: "EBEBF5")
            )
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(for: date) ?? ""
    }
}
