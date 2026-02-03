import SwiftUI
import MagicKit

/// 状态栏弹窗视图
struct StatusBarPopupView: View {
    // MARK: - Properties

    /// 插件提供的弹窗视图
    let pluginPopupViews: [AnyView]

    /// 插件菜单项
    let pluginMenuItems: [NSMenuItem]

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

            Divider()

            // 第二部分：插件提供的视图（如果有）
            if !pluginPopupViews.isEmpty {
                pluginViewsSection

                Divider()
            }

            // 第三部分：菜单项
            menuItemsSection
        }
        .frame(width: 300)
        .background(Color(nsColor: .windowBackgroundColor))
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

                    Text("系统工具箱")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text("v\(appVersion)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
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
                    Divider()
                        .padding(.horizontal, 12)
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Menu Items Section

    private var menuItemsSection: some View {
        VStack(spacing: 0) {
            // 打开 Lumi
            MenuItemRow(
                icon: "window.rectangle",
                title: "打开 Lumi",
                subtitle: "显示主窗口",
                action: onShowMainWindow
            )

            Divider()
                .padding(.horizontal, 8)

            // 检查更新
            MenuItemRow(
                icon: "arrow.down.circle",
                title: "检查更新",
                subtitle: "获取最新版本",
                action: onCheckForUpdates
            )

            if !pluginMenuItems.isEmpty {
                Divider()
                    .padding(.horizontal, 8)

                // 插件菜单项
                ForEach(pluginMenuItems.indices, id: \.self) { index in
                    let item = pluginMenuItems[index]

                    PluginMenuItemRow(menuItem: item)

                    if index < pluginMenuItems.count - 1 {
                        Divider()
                            .padding(.horizontal, 8)
                    }
                }
            }

            Divider()
                .padding(.horizontal, 8)

            // 退出应用
            MenuItemRow(
                icon: "power",
                title: "退出 Lumi",
                subtitle: "完全退出应用",
                color: .red,
                action: onQuit
            )
        }
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}

// MARK: - Menu Item Row

struct MenuItemRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var color: Color = .primary
    let action: () -> Void
    
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(isHovering ? .white : color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundColor(isHovering ? .white : color)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(isHovering ? .white.opacity(0.8) : .secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovering ? Color(nsColor: .selectedContentBackgroundColor) : Color.clear)
                .padding(.horizontal, 4)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Plugin Menu Item Row

struct PluginMenuItemRow: View {
    let menuItem: NSMenuItem
    @State private var isHovering = false

    var body: some View {
        Button(action: {
            if let action = menuItem.action {
                _ = menuItem.target?.perform(action, with: menuItem)
            }
        }) {
            HStack(spacing: 12) {
                if let image = menuItem.image {
                    Image(nsImage: image)
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 16, height: 16)
                        .foregroundColor(isHovering ? .white : .primary)
                } else {
                    Spacer()
                        .frame(width: 24, height: 1)
                }

                Text(menuItem.title)
                    .font(.system(size: 13))
                    .foregroundColor(isHovering ? .white : .primary)

                Spacer()

                let keyEquivalent = menuItem.keyEquivalent
                if !keyEquivalent.isEmpty {
                    Text(keyEquivalent.uppercased())
                        .font(.system(size: 11))
                        .foregroundColor(isHovering ? .white.opacity(0.8) : .secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!menuItem.isEnabled)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovering && menuItem.isEnabled ? Color(nsColor: .selectedContentBackgroundColor) : Color.clear)
                .padding(.horizontal, 4)
        )
        .onHover { hovering in
            if menuItem.isEnabled {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Preview

#Preview("StatusBar Popup") {
    StatusBarPopupView(
        pluginPopupViews: [],
        pluginMenuItems: [],
        onShowMainWindow: {},
        onCheckForUpdates: {},
        onQuit: {}
    )
}
