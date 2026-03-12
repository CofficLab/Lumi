import MagicKit
import OSLog
import SwiftUI

// MARK: - User Message Header

/// 用户消息头部组件
/// 显示时间和简单控制按钮
struct UserMessageHeader: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "📋"
    /// 是否启用详细日志
    nonisolated static let verbose = false

    /// 消息对象
    let message: ChatMessage
    /// 原始消息显示状态绑定
    @Binding var showRawMessage: Bool
    /// 是否是最后一条消息
    let isLastMessage: Bool

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // 用户标识
            HStack(alignment: .center, spacing: 4) {
                Text("你")
                    .font(DesignTokens.Typography.caption1)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
            }

            Spacer()

            HStack(alignment: .center, spacing: 12) {
                // 时间戳
                Text(formatTimestamp(message.timestamp))
                    .font(DesignTokens.Typography.caption2)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                // 切换原始消息按钮
                rawMessageToggleButton
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.primary.opacity(0.02))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    /// 原始消息切换按钮
    private var rawMessageToggleButton: some View {
        RawMessageToggleButton(showRawMessage: $showRawMessage)
    }

    /// 格式化时间戳
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(for: date) ?? ""
    }
}

#Preview("User Message Header") {
    UserMessageHeader(
        message: ChatMessage(role: .user, content: "Hello"),
        showRawMessage: .constant(false),
        isLastMessage: true
    )
    .padding()
    .background(Color.black)
}
