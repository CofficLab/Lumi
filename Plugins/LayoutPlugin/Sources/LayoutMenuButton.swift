import LumiCoreKit
import SwiftUI

/// 工具栏右侧的布局菜单按钮
///
/// 提供下拉菜单，控制各面板区域的显示/隐藏。
public struct LayoutMenuButton: View {
    let layoutContext: LayoutControlContext

    public init(layoutContext: LayoutControlContext) {
        self.layoutContext = layoutContext
    }

    public var body: some View {
        Menu {
            Toggle(isOn: layoutContext.editorVisible) {
                Label(String(localized: "Editor", bundle: .module), systemImage: "rectangle.center.inset.filled")
            }
            Toggle(isOn: layoutContext.contentPanelVisible) {
                Label(String(localized: "Content Panel", bundle: .module), systemImage: "rectangle.topthird.inset.filled")
            }
            Toggle(isOn: layoutContext.bottomPanelVisible) {
                Label(String(localized: "Bottom Panel", bundle: .module), systemImage: "square.bottomthird.inset.filled")
            }
            Toggle(isOn: layoutContext.railVisible) {
                Label(String(localized: "Rail", bundle: .module), systemImage: "sidebar.right")
            }
            Divider()
            Toggle(isOn: layoutContext.rightSidebarVisible) {
                Label(String(localized: "Right Sidebar", bundle: .module), systemImage: "rectangle.rightthird.inset.filled")
            }
        } label: {
            Image(systemName: "sidebar.leading")
                .font(.system(size: 11, weight: .medium))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 22, height: 22)
        .fixedSize()
        .help(String(localized: "Layout", bundle: .module))
    }
}
