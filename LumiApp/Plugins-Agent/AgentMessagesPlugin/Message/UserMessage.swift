import MagicKit
import OSLog
import SwiftUI

// MARK: - User Message
//
/// 负责完整渲染一条用户消息（包含头部与正文）
struct UserMessage: View, SuperLog {
    nonisolated static let emoji = "👤"
    nonisolated static let verbose = false

    let message: ChatMessage
    @Binding var showRawMessage: Bool

    @EnvironmentObject private var agentProvider: AgentVM
    @State private var isHovered: Bool = false

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
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            // 用户标识
            HStack(alignment: .center, spacing: 4) {
                Text(currentUserName)
                    .font(DesignTokens.Typography.caption1)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
            }

            Spacer()

            HStack(alignment: .center, spacing: 12) {
                // 复制按钮
                CopyMessageButton(
                    content: message.content,
                    showFeedback: .constant(false)
                )

                // 重发按钮：仅对用户消息生效
                Button {
                    resend()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .medium))
                        Text("重发")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(DesignTokens.Color.semantic.textSecondary.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
                .help("重新发送该消息")

                // 时间戳
                Text(formatTimestamp(message.timestamp))
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                // 切换原始消息按钮
                RawMessageToggleButton(showRawMessage: $showRawMessage)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.primary.opacity(0.02))
        )
        .contentShape(Rectangle())
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(for: date) ?? ""
    }

    private func resend() {
        agentProvider.sendMessage(input: message.content, images: [])
    }
}
