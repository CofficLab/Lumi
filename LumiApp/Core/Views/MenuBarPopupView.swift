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
                color: Color(hex: "FF453A"),
                action: onQuit
            )
        }
    }

}

// MARK: - Menu Item Row

struct MenuItemRow: View {
    let title: String
    var color: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassRow {
                HStack(spacing: 12) {
                    Text(title)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(color)
                        .padding(.horizontal, 8)

                    Spacer()
                }
            }
        }
        .buttonStyle(.plain)
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
