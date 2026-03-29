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

            PlainTextMessageContentView(
                content: message.content,
                monospaced: false
            )
            .messageBubbleStyle(role: message.role, isError: message.isError)
        }
    }

    // MARK: - Header

    private var header: some View {
        MessageHeaderView {
            AppIdentityRow(title: currentUserName)
        } trailing: {
            HStack(alignment: .center, spacing: 12) {
                CopyMessageButton(
                    content: message.content,
                    showFeedback: .constant(false)
                )

                AppIconButton(
                    systemImage: "arrow.clockwise",
                    label: "重发",
                    tint: AppUI.Color.semantic.textSecondary.opacity(0.8),
                    size: .regular
                ) {
                    resend()
                }
                .help("重新发送该消息")

                Text(formatTimestamp(message.timestamp))
                    .font(AppUI.Typography.caption2)
                    .foregroundColor(AppUI.Color.semantic.textSecondary)

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
