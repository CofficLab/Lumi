import SwiftUI

/// 应用信息图标按钮：显示应用信息图标，点击后弹出详情面板
struct AppInfoIconButton: View {
    /// 是否显示弹出面板
    @State private var showPopover = false

    var body: some View {
        Button(action: {
            showPopover.toggle()
        }) {
            Image(systemName: AppInfoPlugin.iconName)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .help("显示应用信息")
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            AppInfoPopoverView {
                showPopover = false
            }
        }
    }
}

// MARK: - Preview

#Preview("App Info Icon Button") {
    AppInfoIconButton()
        .padding()
}

#Preview("App - Small Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 1200, height: 1200)
}
