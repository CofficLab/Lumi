import MagicKit
import OSLog
import SwiftUI

// MARK: - System Message
//
/// 负责完整渲染一条系统消息（包含头部与正文）
struct SystemMessage: View, SuperLog {
    nonisolated static let emoji = "🛠"
    nonisolated static let verbose = false

    let message: ChatMessage
    @Binding var showRawMessage: Bool

    @State private var isHovered: Bool = false

    var body: some View {
        Group {
            if message.isToolOutput {
                // 工具输出消息：使用专用样式，不展示 System 头部
                VStack(alignment: .leading, spacing: 4) {
                    RoleLabel.tool
                    ToolOutputView(message: message)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    header

                    MarkdownMessageView(
                        message: message,
                        showRawMessage: showRawMessage,
                        isCollapsible: false,
                        isExpanded: true,
                        onToggleExpand: {}
                    )
                    .messageBubbleStyle(role: message.role, isError: message.isError)
                }
            }
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
            // 系统标识
            HStack(alignment: .center, spacing: 4) {
                Text("System")
                    .font(DesignTokens.Typography.caption1)
                    .fontWeight(.medium)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }

            Spacer()

            HStack(alignment: .center, spacing: 12) {
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
                .fill(isHovered ? Color.primary.opacity(0.04) : Color.primary.opacity(0.015))
        )
        .contentShape(Rectangle())
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(for: date) ?? ""
    }
}

