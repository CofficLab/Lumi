import MagicKit
import SwiftUI

/// 状态栏弹窗视图
struct StatusBarPopupView: View {
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
            // 第一部分：应用基本信息
            appInfoSection

            GlassDivider()

            // 第二部分：插件提供的视图（如果有）
            if !pluginPopupViews.isEmpty {
                pluginViewsSection

                GlassDivider()
            }

            // 第三部分：菜单项
            menuItemsSection
        }
        .frame(width: 300)
        .background(DesignTokens.Material.glass)
    }

    // MARK: - App Info Section

    private var appInfoSection: some View {
        VStack(spacing: 12) {
            // 应用图标和名称
            HStack(spacing: 12) {
                // 应用图标
                if let appIcon = NSApp.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 40, height: 40)
                }

                // 应用信息
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lumi")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                    Text("v\(appVersion)")
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                }

                Spacer()
            }
        }
        .padding(12)
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
                color: DesignTokens.Color.semantic.error,
                action: onQuit
            )
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
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
                        .font(DesignTokens.Typography.body)
                        .foregroundColor(color)
                        .padding(.horizontal, DesignTokens.Spacing.sm)

                    Spacer()
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("StatusBar Popup") {
    StatusBarPopupView(
        pluginPopupViews: [],
        onShowMainWindow: {},
        onCheckForUpdates: {},
        onQuit: {}
    )
    .inRootView()
}
