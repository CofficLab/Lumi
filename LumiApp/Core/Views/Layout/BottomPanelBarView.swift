import SwiftUI

/// 全局底部面板视图
///
/// 由内核统一维护，聚合所有插件提供的 `BottomPanelTab`，
/// 渲染统一的 Tab 栏 + 内容切换器。各插件只需提供 Tab 入口
/// （图标 + 标题 + 内容视图），无需关心 Tab 栏的渲染和切换逻辑。
struct BottomPanelBarView: View {
    @EnvironmentObject private var pluginProvider: PluginVM
    @EnvironmentObject private var themeVM: ThemeVM

    /// 当前选中的 Tab ID
    @State private var activeTabId: String?

    var body: some View {
        let tabs = pluginProvider.getBottomPanelTabs()

        VStack(spacing: 0) {
            // Tab 栏（始终显示）
            tabBar(tabs: tabs)

            // 内容区（有选中 Tab 时显示）
            if let activeTabId, let content = pluginProvider.getBottomPanelContentView(tabId: activeTabId) {
                Divider()
                content
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
                    // Bottom Panel 内容切换时平滑过渡
                    .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                    .id(activeTabId)
            }
        }
        .frame(maxWidth: .infinity)
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

    // MARK: - Tab Bar

    private func tabBar(tabs: [BottomPanelTab]) -> some View {
        HStack(spacing: 8) {
            ForEach(tabs) { tab in
                Button {
                    activeTabId = tab.id
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 10, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 11, weight: activeTabId == tab.id ? .semibold : .medium))
                    }
                    .foregroundColor(activeTabId == tab.id
                        ? themeVM.activeAppTheme.workspaceTextColor()
                        : themeVM.activeAppTheme.workspaceSecondaryTextColor())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(activeTabId == tab.id
                                ? themeVM.activeAppTheme.workspaceTextColor().opacity(0.08)
                                : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                // Tab 选中状态变化时平滑过渡
                .animation(.easeInOut(duration: 0.15), value: activeTabId == tab.id)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.05))
    }
}
