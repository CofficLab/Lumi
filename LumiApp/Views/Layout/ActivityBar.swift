import LumiUI
import SwiftUI

/// 活动栏：最左侧的窄图标导航栏（48px 固定宽度）
///
/// 聚合所有提供 `addViewContainer()` 的插件图标，
/// 点击后更新 `WindowLayoutVM.activeViewContainerIcon`，驱动面板内容区切换。
///
/// 主题适配：背景、图标颜色、选中指示条均跟随当前主题。
struct ActivityBar: View {
    @EnvironmentObject var pluginProvider: AppPluginVM
    @EnvironmentObject var layoutVM: WindowLayoutVM
    @EnvironmentObject var themeVM: AppThemeVM

    /// 图标栏宽度
    static let width: CGFloat = 48

    var body: some View {
        let iconItems = pluginProvider.getViewContainerItems()
        let activeIcon = layoutVM.activeViewContainerIcon
        let theme = themeVM.activeChromeTheme

        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(iconItems) { item in
                        ActivityBarButton(
                            icon: item.icon,
                            title: item.title,
                            isSelected: item.icon == activeIcon
                        ) {
                            layoutVM.activeViewContainerIcon = item.icon
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
            let items = pluginProvider.getViewContainerItems()
            layoutVM.restoreSelectedTab(from: items.map(\.id))
            // 首次回退（无磁盘记录时设置默认图标）由 LayoutPlugin 统一负责，
            // 此处不再设置 activeViewContainerIcon，避免与 LayoutPlugin 恢复竞态。
        }
        .onChange(of: pluginProvider.getViewContainerItems()) { _, newItems in
            layoutVM.restoreSelectedTab(from: newItems.map(\.id))
        }
    }
}

// MARK: - Activity Bar Button

/// VS Code 风格的视图容器图标按钮
///
/// 主题适配：选中指示条和图标颜色均跟随当前主题。
struct ActivityBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @EnvironmentObject private var themeVM: AppThemeVM

    var body: some View {
        let theme = themeVM.activeChromeTheme

        AppActivityIconButton(
            systemImage: icon,
            label: title,
            isActive: isSelected,
            activeTint: theme.workspaceTextColor(),
            inactiveTint: theme.workspaceSecondaryTextColor(),
            hoverTint: theme.workspaceTextColor().opacity(0.8),
            indicatorTint: theme.accentColors().primary,
            action: action
        )
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
