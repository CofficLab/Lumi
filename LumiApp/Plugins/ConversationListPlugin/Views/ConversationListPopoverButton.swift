import SwiftUI

/// 工具栏上的会话列表入口按钮
///
/// 在窗口工具栏右上角显示一个聊天气泡图标，点击后弹出 Popover
/// 展示完整的会话列表，支持选择、删除、分页加载等操作。
struct ConversationListPopoverButton: View {
    @EnvironmentObject private var themeVM: ThemeVM
    @State private var isPresented = false

    private let iconSize: CGFloat = 14
    private let iconButtonSize: CGFloat = 28

    var body: some View {
        let theme = themeVM.activeAppTheme

        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "message.fill")
                .font(.system(size: iconSize))
                .foregroundColor(theme.workspaceSecondaryTextColor())
                .frame(width: iconButtonSize, height: iconButtonSize)
                .clipShape(Circle())
        }
        .help("会话列表")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ConversationListView()
                .frame(width: 300, height: 480)
        }
    }
}

// MARK: - Preview

#Preview("Conversation List Popover Button") {
    ConversationListPopoverButton()
        .padding()
        .inRootView()
}
