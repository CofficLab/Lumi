import LumiKernel
import LumiUI
import SwiftUI

/// 工具栏右上角的「布局」入口按钮。
///
/// 使用 `AppIconButton` 渲染，与「开启新会话」「会话列表」等工具栏按钮共享
/// 视觉语言：圆角胶囊背景、统一的 icon + 文字排版、统一的 hover / active 反馈。
/// 点击后弹出 Popover，用于切换「右侧栏」「底部面板」的显隐。
public struct LayoutMenuButton: View {
    @LumiTheme private var theme
    @ObservedObject private var kernel: LumiKernel
    @State private var isPopoverPresented = false

    public init(kernel: LumiKernel) {
        self._kernel = ObservedObject(wrappedValue: kernel)
    }

    public var body: some View {
        let layoutManager = kernel.layoutManager

        return AppIconButton(
            systemImage: "sidebar.leading",
            label: LumiPluginLocalization.string("Layout"),
            isActive: isPopoverPresented
        ) {
            isPopoverPresented.toggle()
        }
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                LayoutPopoverToggle(
                    isOn: Binding(
                        get: { layoutManager?.layoutState.isChatVisible ?? true },
                        set: { layoutManager?.layoutState.setChatVisible($0) }
                    ),
                    icon: "rectangle.rightthird.inset.filled",
                    title: LumiPluginLocalization.string("Right Sidebar")
                )

                Divider()
                    .padding(.vertical, 4)

                LayoutPopoverToggle(
                    isOn: Binding(
                        get: { layoutManager?.layoutState.isPanelVisible ?? true },
                        set: { layoutManager?.layoutState.setPanelVisible($0) }
                    ),
                    icon: "rectangle.inset.filled",
                    title: LumiPluginLocalization.string("Bottom Panel")
                )
            }
            .padding(12)
            .frame(minWidth: 180, alignment: .leading)
            .appSurface(style: .popover, cornerRadius: 8, borderColor: theme.divider)
            .appThemedAppearance()
            .background {
                ThemeWindowAppearanceBridge()
            }
        }
        .help(LumiPluginLocalization.string("Layout"))
    }
}


