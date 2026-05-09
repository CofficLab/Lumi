import SwiftUI

/// 工具栏上的历史数据入口按钮
///
/// 在窗口工具栏右上角显示一个数据库图标，点击后弹出 Popover
/// 展示消息/对话历史数据，支持 Tab 切换和分页浏览。
struct HistoryDBToolbarButton: View {
    @EnvironmentObject private var themeVM: ThemeVM
    @EnvironmentObject private var chatHistoryVM: ChatHistoryVM
    @EnvironmentObject private var conversationVM: ConversationVM
    @State private var isPresented = false

    private let iconSize: CGFloat = 14
    private let iconButtonSize: CGFloat = 28

    var body: some View {
        let theme = themeVM.activeAppTheme

        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "tablecells")
                .font(.system(size: iconSize))
                .foregroundColor(theme.workspaceSecondaryTextColor())
                .frame(width: iconButtonSize, height: iconButtonSize)
                .clipShape(Circle())
        }
        .help(String(localized: "History DB", table: "HistoryDBStatusBar"))
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            HistoryDBDetailView(
                chatHistoryVM: chatHistoryVM,
                conversationVM: conversationVM
            )
            .frame(width: 720, height: 520)
        }
    }
}

// MARK: - Preview

#Preview("History DB Toolbar Button") {
    HistoryDBToolbarButton()
        .padding()
        .inRootView()
}
