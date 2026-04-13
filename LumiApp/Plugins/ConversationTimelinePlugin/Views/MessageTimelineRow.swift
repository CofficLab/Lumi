import MagicKit
import SwiftUI

// MARK: - 消息时间线行

/// 消息时间线行视图
struct MessageTimelineRow: View {
    let item: MessageTimelineItem
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            // 时间轴线和节点
            timelineIndicator

            // 消息内容
            messageContent
        }
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? DesignTokens.Color.semantic.primary.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? DesignTokens.Color.semantic.primary.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: DesignTokens.Duration.micro)) {
                isHovered = hovering
            }
        }
    }

    /// 时间轴指示器
    private var timelineIndicator: some View {
        VStack(spacing: 0) {
            // 节点圆点
            Circle()
                .fill(roleColor)
                .frame(width: 8, height: 8)

            // 连接线
            Rectangle()
                .fill(roleColor.opacity(0.3))
                .frame(width: 2)
                .frame(maxHeight: .infinity)
        }
    }

    /// 消息内容卡片
    private var messageContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 消息头部：角色和时间
            HStack(spacing: 6) {
                Image(systemName: roleIcon)
                    .font(.system(size: 10))
                    .foregroundColor(roleColor)

                Text(roleLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(roleColor)

                Spacer()

                Text(formattedTime)
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }

            // 消息预览（只显示前50个字符）
            Text(messagePreview)
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // 元数据行（模型 / token 统计）
            metadataRow
        }
        .padding(DesignTokens.Spacing.sm)
    }

    // MARK: - 元数据行（模型 + Token）

    @ViewBuilder
    private var metadataRow: some View {
        let hasModelInfo = item.providerId != nil && item.modelName != nil
        let hasTokenInfo = item.inputTokens != nil || item.outputTokens != nil
        let totalTokens = (item.inputTokens ?? 0) + (item.outputTokens ?? 0)

        if hasModelInfo || hasTokenInfo {
            HStack(spacing: 12) {
                // 模型信息
                if hasModelInfo {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(.system(size: 9))
                        Text("\(item.providerId!) / \(item.modelName!)")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }

                // Token 信息（仅在有值时显示）
                if hasTokenInfo {
                    HStack(spacing: 4) {
                        if let input = item.inputTokens {
                            Label("\(formatToken(input))", systemImage: "arrow.down.circle.fill")
                                .font(.system(size: 10))
                        }
                        if let output = item.outputTokens {
                            Label("\(formatToken(output))", systemImage: "arrow.up.circle.fill")
                                .font(.system(size: 10))
                        }
                        if totalTokens > 0 {
                            Text("总计 \(formatToken(totalTokens))")
                                .font(.system(size: 10))
                                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        }
                    }
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
            }
        }
    }

    // MARK: - 辅助计算属性

    /// 消息预览文本（最多50个字符）
    private var messagePreview: String {
        let content = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if content.isEmpty {
            return "[空内容]"
        }
        if content.count <= 50 {
            return content
        }
        let index = content.index(content.startIndex, offsetBy: 50)
        return String(content[..<index]) + "..."
    }

    /// 格式化的时间字符串
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: item.timestamp)
    }

    /// 角色图标
    private var roleIcon: String {
        switch item.role {
        case .user:
            return "person.circle.fill"
        case .assistant:
            return "brain.head.profile"
        case .system:
            return "gear.circle.fill"
        case .tool:
            return "wrench.and.screwdriver.fill"
        case .status:
            return "hourglass.circle.fill"
        case .error:
            return "xmark.circle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    /// 角色标签
    private var roleLabel: String {
        switch item.role {
        case .user:
            return "用户"
        case .assistant:
            return "助手"
        case .system:
            return "系统"
        case .tool:
            return "工具"
        case .status:
            return "状态"
        case .error:
            return "错误"
        case .unknown:
            return "未知"
        }
    }

    /// 角色颜色
    private var roleColor: Color {
        switch item.role {
        case .user:
            return .blue
        case .assistant:
            return .green
        case .system:
            return .orange
        case .tool:
            return .purple
        case .status:
            return .cyan
        case .error:
            return .red
        case .unknown:
            return .gray
        }
    }
}
