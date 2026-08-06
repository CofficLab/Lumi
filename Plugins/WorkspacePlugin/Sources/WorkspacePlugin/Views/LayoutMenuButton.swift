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
        let layoutManager = kernel.workspace

        return AppIconButton(
            systemImage: "sidebar.leading",
            isActive: isPopoverPresented
        ) {
            isPopoverPresented.toggle()
        }
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                AppToggleRow(
                    title: LocalizedStringKey(LumiPluginLocalization.string("Right Sidebar")),
                    systemImage: "rectangle.rightthird.inset.filled",
                    isOn: Binding(
                        get: { layoutManager?.isChatVisible ?? true },
                        set: { layoutManager?.setChatVisible($0) }
                    )
                )

                AppToggleRow(
                    title: LocalizedStringKey(LumiPluginLocalization.string("Bottom Panel")),
                    systemImage: "rectangle.bottomthird.inset.filled",
                    isOn: Binding(
                        get: { layoutManager?.isPanelBottomVisible ?? true },
                        set: { layoutManager?.setPanelBottomVisible($0) }
                    )
                )
            }
            .frame(minWidth: 220, alignment: .leading)
            .appSurface(style: .popover, cornerRadius: 8, borderColor: theme.divider)
            .appThemedAppearance()
            .background {
                ThemeWindowAppearanceBridge()
            }
        }
        .help(LumiPluginLocalization.string("Layout"))
    }
}
