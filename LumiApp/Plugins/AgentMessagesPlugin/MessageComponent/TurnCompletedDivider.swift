import MagicKit
import SwiftUI

// MARK: - Turn Completed Divider

/// 对话轮次结束的分隔线视图
/// 显示为一条横线，中间写上"结束"和时间
struct TurnCompletedDivider: View {
    let message: ChatMessage

    @EnvironmentObject private var projectVM: ProjectVM

    private var endText: String {
        switch projectVM.languagePreference {
        case .chinese:
            return "结束"
        case .english:
            return "End"
        }
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: message.timestamp)
    }

    var body: some View {
        HStack(spacing: 12) {
            // 左侧横线
            Rectangle()
                .fill(AppUI.Color.semantic.textSecondary.opacity(0.3))
                .frame(height: 1)

            // 中间文字：结束 + 时间
            HStack(spacing: 6) {
                Text(endText)
                    .font(AppUI.Typography.caption1)
                    .fontWeight(.medium)
                
                Text(timeText)
                    .font(AppUI.Typography.caption2)
            }
            .foregroundColor(AppUI.Color.semantic.textSecondary)

            // 右侧横线
            Rectangle()
                .fill(AppUI.Color.semantic.textSecondary.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.vertical, 8)
    }
}