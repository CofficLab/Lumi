import SwiftUI
import MagicKit

/// 会话列表头部视图
/// 显示在会话列表顶部，包含图标和标题文字
struct ConversationListHeader: View {
    var body: some View {
        HStack {
            // 消息图标
            Image(systemName: "message.fill")
                .font(.system(size: 14))
                .foregroundColor(.accentColor)

            // 标题文字
            Text("对话历史")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

// MARK: - View

extension ConversationListHeader {
    /// 图标视图：橙色消息填充图标
    private var iconView: some View {
        Image(systemName: "message.fill")
            .font(.system(size: 14))
            .foregroundColor(.accentColor)
    }

    /// 标题视图：对话历史文字
    private var titleView: some View {
        Text("对话历史")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(DesignTokens.Color.semantic.textPrimary)
    }
}

// MARK: - Preview

#Preview("列表头部 - 标准尺寸") {
    ConversationListHeader()
        .frame(width: 220)
}

#Preview("列表头部 - 窄屏") {
    ConversationListHeader()
        .frame(width: 180)
}
