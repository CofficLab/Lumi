import LumiUI
import SwiftUI

/// 标题栏右侧的对话条数徽标。
///
/// 显示当前作用域内的对话条数（与列表口径一致：顶层对话，不含子 Agent 会话）。
///
/// 徽标可点击：点击后弹出「对话统计」面板，展示每日对话数量折线图，
/// 并提供按时间批量清理历史对话的入口。
///
/// 视觉规格刻意压到最小：10pt 半粗体 + 等宽数字，胶囊底色用主题的次级文字色，
/// 这样它在标题栏里只做「计数提示」，不会与标题抢占注意力。
struct ConversationCountBadge: View {
    @LumiTheme private var theme: any LumiUITheme

    let count: Int
    /// 点击徽标时触发的动作。
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(count)")
                .font(.system(size: 10, weight: .semibold))
                // 等宽数字：条数变化时数字宽度不变，徽标不会左右抖动。
                .monospacedDigit()
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    Capsule().fill(theme.textSecondary.opacity(0.14))
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("查看对话统计")
    }

    private var accessibilityLabel: String {
        count == 1 ? "1 个对话" : "\(count) 个对话"
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 8) {
        ConversationCountBadge(count: 0) {}
        ConversationCountBadge(count: 7) {}
        ConversationCountBadge(count: 128) {}
    }
    .padding(.vertical, 12)
    .frame(width: 160)
    .background(Color.gray.opacity(0.15))
}
