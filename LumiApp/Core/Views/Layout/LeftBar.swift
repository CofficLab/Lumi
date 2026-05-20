import MagicKit
import LumiUI
import SwiftUI

/// 活动栏：最左侧的窄图标导航栏（48px 固定宽度）
///
/// 聚合所有提供 `addPanelIcon()` 的插件图标，
/// 点击后更新 `AppPluginVM.activePanelIcon`，驱动内容面板切换。
///
/// 主题适配：背景、图标颜色、选中指示条均跟随当前主题。
struct ActivityBar: View {
    @EnvironmentObject var pluginProvider: AppPluginVM
    @EnvironmentObject var layoutVM: WindowLayoutVM
    @EnvironmentObject var themeVM: AppThemeVM

    /// 图标栏宽度
    static let width: CGFloat = 48

    var body: some View {
        let iconItems = pluginProvider.getPanelIconItems()
        let activeIcon = pluginProvider.activePanelIcon
        let theme = themeVM.activeAppTheme

        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(iconItems) { item in
                        ActivityBarButton(
                            icon: item.icon,
                            title: item.title,
                            isSelected: item.icon == activeIcon
                        ) {
                            pluginProvider.activePanelIcon = item.icon
                            layoutVM.selectAgentSidebarTab(item.id, reason: "Activity bar clicked")
                        }
                    }
                }
                .padding(.top, 8)
            }

            Spacer()

            ActivityBarButton(
                icon: "gearshape",
                title: "设置",
                isSelected: false
            ) {
                NotificationCenter.postOpenSettings()
            }
            .padding(.bottom, 8)
        }
        .frame(width: Self.width)
        .background(theme.sidebarBackgroundColor())
        .onAppear {
            let items = pluginProvider.getPanelIconItems()
            layoutVM.restoreSelectedTab(from: items.map(\.id))
            // 如果 LayoutPlugin 尚未恢复图标（或恢复的图标已失效），回退到第一个
            if pluginProvider.activePanelIcon == nil {
                if let first = items.first {
                    pluginProvider.activePanelIcon = first.icon
                }
            }
        }
        .onChange(of: pluginProvider.getPanelIconItems()) { _, newItems in
            layoutVM.restoreSelectedTab(from: newItems.map(\.id))
        }
    }
}

// MARK: - Activity Bar Button

/// VS Code 风格的活动栏图标按钮
///
/// 主题适配：选中指示条和图标颜色均跟随当前主题。
struct ActivityBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @LumiMotionPreferenceReader private var motionPreference
    @EnvironmentObject private var themeVM: AppThemeVM
    @State private var isHovered = false

    var body: some View {
        let theme = themeVM.activeAppTheme

        Button(action: action) {
            ZStack(alignment: .leading) {
                // 选中指示条：添加过渡动画
                if isSelected {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(theme.accentColors().primary)
                        .frame(width: 2.5, height: 20)
                        .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))
                }

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor(theme: theme))
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .contentShape(Rectangle())
                    .scaleEffect(isHovered && !isSelected && motionPreference.allowsMotion ? LumiMotion.hoverScale : 1.0)
            }
        }
        .buttonStyle(.plain)
        .help(title)
        // 选中状态变化时平滑过渡
        .animation(LumiMotion.enabled(LumiMotion.selection, preference: motionPreference), value: isSelected)
        .onHover { hovering in
            LumiMotion.animate(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference)) {
                isHovered = hovering
            }
        }
    }

    // MARK: - Private

    /// 根据主题计算图标颜色
    private func iconColor(theme: any SuperTheme) -> Color {
        if isSelected {
            return theme.workspaceTextColor()
        }
        if isHovered {
            return theme.workspaceTextColor().opacity(0.8)
        }
        return theme.workspaceSecondaryTextColor()
    }
}

// MARK: - Preview

#if os(macOS)
    #Preview("Activity Bar") {
        ActivityBar()
            .frame(width: 48, height: 600)
            .inRootView()
    }
#endif
