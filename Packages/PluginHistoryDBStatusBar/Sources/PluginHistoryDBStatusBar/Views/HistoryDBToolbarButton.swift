import SwiftUI
import LumiUI

/// 工具栏上的历史数据入口按钮
///
/// 在窗口工具栏右上角显示一个数据库图标，点击后弹出 Popover
/// 展示消息/对话历史数据，支持 Tab 切换和分页浏览。
public struct HistoryDBToolbarButton: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @State private var isPresented = false

    private let iconSize: CGFloat = 14
    private let iconButtonSize: CGFloat = 28

    public var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "tablecells")
                .font(.system(size: iconSize))
                .foregroundColor(theme.textSecondary)
                .frame(width: iconButtonSize, height: iconButtonSize)
                .clipShape(Circle())
        }
        .help(String(localized: "History DB", table: "HistoryDBStatusBar"))
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            HistoryDBDetailView()
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
