import SwiftUI
import LumiUI

/// 菜单栏弹窗视图
struct MenuBarPopupView: View {
    // MARK: - Properties

    /// 插件提供的弹窗视图
    let pluginPopupViews: [AnyView]

    /// 显示主窗口
    let onShowMainWindow: () -> Void

    /// 检查更新
    let onCheckForUpdates: () -> Void

    /// 退出应用
    let onQuit: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 第一部分：插件提供的视图（如果有）
            if !pluginPopupViews.isEmpty {
                pluginViewsSection

                GlassDivider()
            }

            // 第二部分：菜单项
            menuItemsSection
        }
        .frame(width: 300)
        .appSurface(style: .glass, cornerRadius: 0)
    }

    // MARK: - Plugin Views Section

    private var pluginViewsSection: some View {
        VStack(spacing: 0) {
            ForEach(pluginPopupViews.indices, id: \.self) { index in
                pluginPopupViews[index]
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)

                if index < pluginPopupViews.count - 1 {
                    GlassDivider()
                }
            }
        }
        .padding(.vertical, 0)
    }

    // MARK: - Menu Items Section

    private var menuItemsSection: some View {
        VStack(spacing: 0) {
            // 打开 Lumi
            MenuItemRow(
                title: "打开 Lumi",
                action: onShowMainWindow
            )

            GlassDivider()

            // 检查更新
            MenuItemRow(
                title: "检查更新",
                action: onCheckForUpdates
            )

            GlassDivider()

            // 退出应用
            MenuItemRow(
                title: "退出 Lumi",
                role: .destructive,
                action: onQuit
            )
        }
    }

}

// MARK: - Menu Item Row

struct MenuItemRow: View {
    enum Role {
        case normal
        case destructive
    }

    let title: String
    var role: Role = .normal
    let action: () -> Void

    @LumiTheme private var theme: any LumiUITheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.appCaption)
                    .foregroundColor(isHovering ? foregroundColor.opacity(0.8) : foregroundColor)
                    .padding(.horizontal, 12)

                Spacer()
            }
            .padding(.vertical, 8)
            .background(isHovering ? theme.appListRowHoverBackground : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var foregroundColor: Color {
        switch role {
        case .normal:
            theme.textPrimary
        case .destructive:
            theme.error
        }
    }
}

// MARK: - Preview

#Preview("Menu Bar Popup") {
    MenuBarPopupView(
        pluginPopupViews: [],
        onShowMainWindow: {},
        onCheckForUpdates: {},
        onQuit: {}
    )
    .inRootView()
}
