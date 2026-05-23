import SwiftUI

/// 工具栏右侧的布局菜单按钮
///
/// 提供下拉菜单，控制各面板区域的显示/隐藏。
struct LayoutMenuButton: View {
    @EnvironmentObject private var layoutVM: WindowLayoutVM
    @EnvironmentObject private var themeVM: AppThemeVM

    var body: some View {
        Menu {
            Toggle(isOn: $layoutVM.contentPanelVisible) {
                Label("Content Panel", systemImage: "rectangle.topthird.inset.filled")
            }
            Toggle(isOn: $layoutVM.bottomPanelVisible) {
                Label("Bottom Panel", systemImage: "square.bottomthird.inset.filled")
            }
        } label: {
            Image(systemName: "sidebar.leading")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
