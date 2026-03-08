import SwiftUI
import MagicKit

/// 会话列表头部视图
/// 显示在会话列表顶部，包含折叠按钮、图标和标题文字
struct ConversationListHeader: View {
    @Binding var isExpanded: Bool

    var body: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)

            Image(systemName: "message.fill")
                .font(.system(size: 14))
                .foregroundColor(.accentColor)

            Text("对话历史")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

// MARK: - Preview

#Preview("列表头部 - 标准尺寸") {
    ConversationListHeader(isExpanded: .constant(true))
        .frame(width: 220)
}

#Preview("列表头部 - 窄屏") {
    ConversationListHeader(isExpanded: .constant(true))
        .frame(width: 180)
}
