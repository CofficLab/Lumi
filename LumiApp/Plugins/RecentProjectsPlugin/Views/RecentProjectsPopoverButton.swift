import SwiftUI

/// 工具栏上的最近项目入口按钮
///
/// 在窗口工具栏右上角显示一个文件夹图标，点击后弹出 Popover
/// 展示完整的项目列表，支持拖拽添加、选择切换等操作。
struct RecentProjectsPopoverButton: View {
    @State private var isPresented = false

    private let iconSize: CGFloat = 14
    private let iconButtonSize: CGFloat = 28

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: iconSize))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
                .frame(width: iconButtonSize, height: iconButtonSize)
                .background(Color.black.opacity(0.05))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help(String(localized: "Recent Projects", table: "RecentProjects"))
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            RecentProjectsSidebarView()
                .frame(width: 300, height: 400)
        }
    }
}

// MARK: - Preview

#Preview("Recent Projects Popover Button") {
    RecentProjectsPopoverButton()
        .padding()
        .inRootView()
}
