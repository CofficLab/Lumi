import MagicKit
import SwiftUI

/// 活动栏：最左侧的窄图标导航栏（48px 固定宽度）
///
/// 聚合所有提供 `addPanelIcon()` 的插件图标，
/// 点击后更新 `PluginVM.activePanelIcon`，驱动内容面板切换。
///
/// 主题适配：背景、图标颜色、选中指示条均跟随当前主题。
struct ActivityBar: View {
    @EnvironmentObject var pluginProvider: PluginVM
    @EnvironmentObject var layoutVM: LayoutVM
    @EnvironmentObject var themeManager: ThemeManager

    /// 图标栏宽度
    static let width: CGFloat = 48

    var body: some View {
        let iconItems = pluginProvider.getPanelIconItems()
        let activeIcon = pluginProvider.activePanelIcon
        let theme = themeManager.activeAppTheme

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
            // 初始化时恢复上次选中的图标，如果无效则回退到第一个
            if pluginProvider.activePanelIcon == nil {
                if let savedIcon = AppSettingStore.loadActivePanelIcon(),
                   items.contains(where: { $0.icon == savedIcon }) {
                    pluginProvider.activePanelIcon = savedIcon
                } else if let first = items.first {
                    pluginProvider.activePanelIcon = first.icon
                }
            }
        }
        .onChange(of: pluginProvider.getPanelIconItems()) { _, newItems in
            layoutVM.restoreSelectedTab(from: newItems.map(\.id))
        }
    }
}

// MARK: - Panel Content View

/// 面板内容视图：显示当前激活插件的面板内容
///
/// 根据 `PluginVM.activePanelIcon` 找到匹配的插件，
/// 通过 `getActivePanelItem()` 获取其面板视图。
/// 每个插件的宽度比例独立持久化（UserDefaults key: `Split.Panel.<pluginId>`）。
struct PanelContentView: View {
    @EnvironmentObject var pluginProvider: PluginVM
    @EnvironmentObject var layoutVM: LayoutVM

    var body: some View {
        let activeItem = pluginProvider.getActivePanelItem()

        Group {
            if let activeItem {
                activeItem.view
                    .background(SplitViewWidthPersistence(storageKey: "Split.Panel.\(activeItem.id)"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
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

    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isHovered = false

    var body: some View {
        let theme = themeManager.activeAppTheme

        Button(action: action) {
            ZStack(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(theme.accentColors().primary)
                        .frame(width: 2.5, height: 20)
                }

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor(theme: theme))
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .help(title)
        .onHover { hovering in
            isHovered = hovering
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
