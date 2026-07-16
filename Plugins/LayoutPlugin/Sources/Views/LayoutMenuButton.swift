import LumiCoreKit
import LumiUI
import SwiftUI

/// 工具栏右上角的「布局」入口按钮。
///
/// 使用 `AppIconButton` 渲染，与「开启新会话」「会话列表」等工具栏按钮共享
/// 视觉语言：圆角胶囊背景、统一的 icon + 文字排版、统一的 hover / active 反馈。
/// 点击后弹出 Popover，用于切换「右侧栏」「底部面板」的显隐。
public struct LayoutMenuButton: View {
    @LumiTheme private var theme
    @ObservedObject private var lumiCore: LumiCore
    @State private var isPopoverPresented = false

    /// 当两个面板都可见时，按钮处于 active 态
    private var isAnyPanelVisible: Bool {
        layoutState.chatSectionVisible || layoutState.bottomPanelVisible
    }

    // layoutState 从 lumiCore 获取
    private var layoutState: LumiLayoutState {
        lumiCore.layoutState ?? LumiLayoutState()
    }

    public init(lumiCore: LumiCore) {
        self._lumiCore = ObservedObject(wrappedValue: lumiCore)
    }

    public var body: some View {
        AppIconButton(
            systemImage: "sidebar.leading",
            label: LumiPluginLocalization.string("Layout", bundle: .module),
            isActive: isPopoverPresented || isAnyPanelVisible
        ) {
            isPopoverPresented.toggle()
        }
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                LayoutPopoverToggle(
                    isOn: Binding(
                        get: { layoutState.chatSectionVisible },
                        set: { layoutState.chatSectionVisible = $0 }
                    ),
                    icon: "rectangle.rightthird.inset.filled",
                    title: LumiPluginLocalization.string("Right Sidebar", bundle: .module)
                )

                Divider()
                    .padding(.vertical, 4)

                LayoutPopoverToggle(
                    isOn: Binding(get: { layoutState.bottomPanelVisible }, set: { layoutState.bottomPanelVisible = $0 }),
                    icon: "rectangle.inset.filled",
                    title: LumiPluginLocalization.string("Bottom Panel", bundle: .module)
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
        .help(LumiPluginLocalization.string("Layout", bundle: .module))
    }
}

private struct LayoutPopoverToggle: View {
    @LumiTheme private var theme
    @Binding var isOn: Bool
    let icon: String
    let title: String

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textPrimary)

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textPrimary)
            }
        }
        .toggleStyle(.checkbox)
    }
}
