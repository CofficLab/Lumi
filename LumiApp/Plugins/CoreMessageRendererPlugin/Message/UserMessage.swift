import MagicKit
import SwiftUI

// MARK: - User Message
//
/// 负责完整渲染一条用户消息（包含头部与正文）
struct UserMessage: View {
    let message: ChatMessage
    @Binding var showRawMessage: Bool

    @EnvironmentObject private var inputQueueVM: InputQueueVM

    /// 当前 macOS 登录用户名称
    private var currentUserName: String {
        let fullName = NSFullUserName()
        return fullName.isEmpty ? NSUserName() : fullName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header

            VStack(alignment: .leading, spacing: 8) {
                if !message.images.isEmpty {
                    UserMessageImageGrid(images: message.images)
                }

                if !message.content.isEmpty {
                    PlainTextMessageContentView(
                        content: message.content,
                        monospaced: false
                    )
                }
            }
            .messageBubbleStyle(role: message.role, isError: message.isError)
        }
    }

    // MARK: - Header

    private var header: some View {
        MessageHeaderView {
            HStack(alignment: .center, spacing: 4) {
                Text(currentUserName)
                    .font(DesignTokens.Typography.caption1)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
            }
        } trailing: {
            HStack(alignment: .center, spacing: 12) {
                CopyMessageButton(
                    content: message.content,
                    showFeedback: .constant(false)
                )

                ResendButton(action: resend)

                Text(formatTimestamp(message.timestamp))
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                RawMessageToggleButton(showRawMessage: $showRawMessage)
            }
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(for: date) ?? ""
    }

    private func resend() {
        inputQueueVM.enqueueText(message.content)
    }
}
