import SwiftUI

/// 全局底部面板视图
///
/// 由内核统一维护，聚合所有插件提供的 `BottomPanelTab`，
/// 渲染统一的 Tab 栏 + 内容切换器。各插件只需提供 Tab 入口
/// （图标 + 标题 + 内容视图），无需关心 Tab 栏的渲染和切换逻辑。
struct BottomPanelBarView: View {
    @EnvironmentObject private var pluginProvider: PluginVM
    @EnvironmentObject private var themeVM: ThemeVM
    @EnvironmentObject private var layoutVM: LayoutVM

    /// 当前选中的 Tab ID
    @State private var activeTabId: String?

    /// Tab 栏高度
    private let tabBarHeight: CGFloat = 33

    /// 面板展开时的默认高度
    private let defaultExpandedHeight: Double = 280

    var body: some View {
        let tabs = pluginProvider.getBottomPanelTabs()

        VStack(spacing: 0) {
            // Tab 栏（始终显示）
            tabBar(tabs: tabs)

            // 内容区（仅在面板展开且有选中 Tab 时显示）
            if isExpanded, let activeTabId, let content = pluginProvider.getBottomPanelContentView(tabId: activeTabId) {
                Divider()
                // 使用计算高度，避免 maxHeight: .infinity 与外部固定高度冲突
                content
                    .frame(maxWidth: .infinity)
                    .frame(height: layoutVM.editorBottomPanelHeight - tabBarHeight - 1)  // 1 = Divider height
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: layoutVM.editorBottomPanelHeight)
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
        .overlay(alignment: .top) {
            Rectangle()
                .fill(themeVM.activeAppTheme.workspaceTextColor().opacity(0.08))
                .frame(height: 1)
        }
        .onAppear {
            // 首次出现时自动选中第一个 Tab
            if activeTabId == nil, let first = tabs.first {
                activeTabId = first.id
            }
        }
        .onChange(of: tabs.map(\.id)) { oldIds, newIds in
            // 当 Tab 列表变化时，如果当前选中的 Tab 不存在了，自动选中第一个
            if let current = activeTabId, !newIds.contains(current) {
                activeTabId = newIds.first
            } else if activeTabId == nil {
                activeTabId = newIds.first
            }
        }
    }

    /// 面板是否处于展开状态
    ///
    /// 拖拽过程中使用锁定状态，避免高度接近临界值时频繁切换导致 Tab 栏抖动。
    private var isExpanded: Bool {
        if layoutVM.isDraggingBottomPanel {
            return layoutVM.wasExpandedBeforeDrag
        }
        return layoutVM.editorBottomPanelHeight > tabBarHeight
    }

    // MARK: - Tab Bar

    private func tabBar(tabs: [BottomPanelTab]) -> some View {
        HStack(spacing: 8) {
            ForEach(tabs) { tab in
                Button {
                    selectTab(tab.id)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 10, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 11, weight: activeTabId == tab.id && isExpanded ? .semibold : .medium))
                    }
                    .foregroundColor(activeTabId == tab.id && isExpanded
                        ? themeVM.activeAppTheme.workspaceTextColor()
                        : themeVM.activeAppTheme.workspaceSecondaryTextColor())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(activeTabId == tab.id && isExpanded
                                ? themeVM.activeAppTheme.workspaceTextColor().opacity(0.08)
                                : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            if isExpanded {
                Button {
                    collapsePanel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.05))
    }

    // MARK: - Actions

    /// 选中某个 Tab 并展开面板
    private func selectTab(_ tabId: String) {
        activeTabId = tabId
        if !isExpanded {
            layoutVM.editorBottomPanelHeight = defaultExpandedHeight
        }
    }

    /// 收起面板（高度回到最小，仅保留 Tab 栏）
    private func collapsePanel() {
        layoutVM.editorBottomPanelHeight = Double(tabBarHeight)
    }
}
