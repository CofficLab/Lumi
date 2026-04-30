import MagicKit
import SwiftUI

/// 活动栏：最左侧的窄图标导航栏（48px 固定宽度）
///
/// 聚合所有提供 `addPanelView()` 的插件图标，
/// 点击后通过 LayoutVM 驱动内容面板切换。
///
/// 主题适配：背景、图标颜色、选中指示条均跟随当前主题。
struct ActivityBar: View {
    @EnvironmentObject var pluginProvider: PluginVM
    @EnvironmentObject var layoutVM: LayoutVM
    @EnvironmentObject var themeManager: ThemeManager

    /// 图标栏宽度
    static let width: CGFloat = 48

    var body: some View {
        let panelItems = pluginProvider.getPanelItems()
        let selectedId = currentSelectedId(in: panelItems)
        let theme = themeManager.activeAppTheme

        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(panelItems) { item in
                        ActivityBarButton(
                            icon: item.icon,
                            title: item.title,
                            isSelected: item.id == selectedId
                        ) {
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
            let items = pluginProvider.getPanelItems()
            layoutVM.restoreSelectedTab(from: items.map(\.id))
        }
        .onChange(of: pluginProvider.getPanelItems()) { _, newItems in
            layoutVM.restoreSelectedTab(from: newItems.map(\.id))
        }
    }

    // MARK: - Helpers

    private func currentSelectedId(in items: [PluginVM.PanelItem]) -> String {
        let id = layoutVM.selectedAgentSidebarTabId
        return items.contains(where: { $0.id == id }) ? id : (items.first?.id ?? "")
    }
}

// MARK: - Panel Content View

/// 面板内容视图：显示当前选中插件的面板内容
///
/// 每个插件的宽度比例独立持久化（UserDefaults key: `Split.Panel.<pluginId>`）。
struct PanelContentView: View {
    @EnvironmentObject var pluginProvider: PluginVM
    @EnvironmentObject var layoutVM: LayoutVM

    var body: some View {
        let panelItems = pluginProvider.getPanelItems()
        let selectedId = layoutVM.selectedAgentSidebarTabId
        let selected = panelItems.first(where: { $0.id == selectedId }) ?? panelItems.first

        Group {
            if let selected {
                selected.view
                    .background(SplitViewWidthPersistence(storageKey: "Split.Panel.\(selected.id)"))
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
