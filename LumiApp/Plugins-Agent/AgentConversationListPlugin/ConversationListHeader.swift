import SwiftUI
import MagicKit

/// 会话列表头部视图
/// 显示在会话列表顶部，包含折叠按钮、图标和标题文字
struct ConversationListHeader: View {
    @Binding var isExpanded: Bool
    @State private var isHovered: Bool = false

    var body: some View {
        HStack {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 16, height: 16)

            Image(systemName: "message.fill")
                .font(.system(size: 14))
                .foregroundColor(.accentColor)

            Text(String(localized: "Conversation History", table: "ConversationList"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppUI.Color.semantic.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
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