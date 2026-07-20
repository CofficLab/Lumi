import LumiUI
import SwiftUI
import LumiKernel

/// 会话列表头部视图
/// 显示在会话列表顶部，包含折叠按钮、图标和标题文字
public struct ConversationListHeader: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @Binding var isExpanded: Bool
    @State private var isHovered: Bool = false

    public var body: some View {
        HStack {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.appMicroEmphasized)
                .foregroundColor(theme.textSecondary)
                .frame(width: 16, height: 16)

            Image(systemName: "message.fill")
                .font(.appCallout)
                .foregroundColor(theme.primary)

            Text(LumiPluginLocalization.string("Conversation History", bundle: .module))
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isHovered ? theme.textSecondary.opacity(0.05) : Color.clear)
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
