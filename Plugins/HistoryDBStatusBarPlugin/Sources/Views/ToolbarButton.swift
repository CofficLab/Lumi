import SwiftUI
import LumiUI
import LumiKernel

/// 工具栏上的历史数据入口按钮
///
/// 在窗口工具栏右上角显示一个数据库图标，点击后弹出 Popover
/// 展示消息/对话历史数据，支持 Tab 切换和分页浏览。
public struct ToolbarButton: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @State private var isPresented = false

    private let historyService: (any HistoryQueryService)?
    private let iconSize: CGFloat = 14
    private let iconButtonSize: CGFloat = 28

    public init(historyService: (any HistoryQueryService)? = nil) {
        self.historyService = historyService
    }

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
        .help(LumiPluginLocalization.string("History DB", bundle: .module))
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            DetailView(historyService: historyService)
            .frame(width: 720, height: 520)
        }
    }
}

// MARK: - Preview

#Preview("History DB Toolbar Button") {
    ToolbarButton()
        .padding()
        .inRootView()
}
