import MagicKit
import SwiftUI

/// 格式化 token 数字（超过 1000 时显示 K）
func formatToken(_ value: Int) -> String {
    if value >= 1000 {
        let k = Double(value) / 1000.0
        return String(format: "%.1fk", k)
    }
    return "\(value)"
}

/// 对话时间线标题栏
struct ConversationTimelineHeader: View {
    let itemCount: Int
    let totalTokens: Int
    let onRefresh: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("对话时间线")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                HStack(spacing: 12) {
                    Text("\(itemCount) 条消息")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                    // 总 Token 数
                    if totalTokens > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 9))
                            Text("总计 \(formatToken(totalTokens)) tokens")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    }
                }
            }

            Spacer()

            // 刷新按钮
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
            .buttonStyle(.plain)
            .help("刷新")
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, DesignTokens.Spacing.md)
        }
    }
}
