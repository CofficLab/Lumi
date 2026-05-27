import SwiftUI

/// 工具栏右侧的布局菜单按钮
///
/// 提供下拉菜单，控制各面板区域的显示/隐藏。
struct LayoutMenuButton: View {
    @EnvironmentObject private var layoutVM: WindowLayoutVM

    var body: some View {
        Menu {
            Toggle(isOn: $layoutVM.editorVisible) {
                Label(String(localized: "Editor"), systemImage: "rectangle.center.inset.filled")
            }
            Toggle(isOn: $layoutVM.contentPanelVisible) {
                Label(String(localized: "Content Panel"), systemImage: "rectangle.topthird.inset.filled")
            }
            Toggle(isOn: $layoutVM.bottomPanelVisible) {
                Label(String(localized: "Bottom Panel"), systemImage: "square.bottomthird.inset.filled")
            }
            Toggle(isOn: $layoutVM.railVisible) {
                Label(String(localized: "Rail"), systemImage: "sidebar.right")
            }
            Divider()
            Toggle(isOn: $layoutVM.rightSidebarVisible) {
                Label(String(localized: "Right Sidebar"), systemImage: "rectangle.rightthird.inset.filled")
            }
        } label: {
            Image(systemName: "sidebar.leading")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }
}
