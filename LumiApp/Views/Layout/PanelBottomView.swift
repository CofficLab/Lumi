import LumiCoreKit
import LumiUI
import SwiftUI

/// 全局底部面板视图
///
/// 由内核统一维护，聚合所有插件提供的 `BottomPanelTab`，
/// 渲染统一的 Tab 栏 + 内容切换器。各插件只需提供 Tab 入口
/// （图标 + 标题 + 内容视图），无需关心 Tab 栏的渲染和切换逻辑。
struct PanelBottomView: View {
    @LumiMotionPreferenceReader private var motionPreference
    @EnvironmentObject private var pluginProvider: AppPluginVM
    @EnvironmentObject private var themeVM: AppThemeVM
    @EnvironmentObject private var layoutVM: WindowLayoutVM
    @Environment(\.windowContainer) private var windowContainer

    /// 当前选中的 Tab ID
    @State private var activeTabId: String?

    var body: some View {
        let activeIcon = layoutVM.activeViewContainerIcon
        let activeContainer = pluginProvider.getActiveViewContainer(activeIcon: activeIcon)
        let pluginContext = PluginContext(
            activeIcon: activeIcon,
            isEditorVisible: layoutVM.editorVisible,
            showChat: activeContainer?.showChat ?? false,
            showsProjectToolbar: activeContainer?.showsProjectToolbar ?? false,
            showsRail: activeContainer?.showsRail ?? false,
            showsBottomPanel: activeContainer?.showsBottomPanel ?? false,
            windowId: windowContainer?.id
        )
        let tabs = pluginProvider.getBottomPanelTabs(context: pluginContext)

        VStack(spacing: 0) {
            // Tab 栏（始终显示）
            tabBar(tabs: tabs)

            // 内容区（有选中 Tab 时显示）
            if let activeTabId, let content = pluginProvider.getBottomPanelContentView(tabId: activeTabId, context: pluginContext) {
                Divider()
                content
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
                    // Bottom Panel 内容切换时平滑过渡
                    .transition(.opacity.animation(LumiMotion.enabled(LumiMotion.reveal, preference: motionPreference)))
                    .id(activeTabId)
            }
        }
        .frame(maxWidth: .infinity)
        .background(themeVM.activeChromeTheme.workspaceBackgroundColor())
        .overlay(alignment: .top) {
            Rectangle()
                .fill(themeVM.activeChromeTheme.workspaceTextColor().opacity(0.08))
                .frame(height: 1)
        }
        .contextMenu {
            Button {
                withAnimation {
                    layoutVM.bottomPanelVisible = false
                }
            } label: {
                Label("Hide Bottom Panel", systemImage: "rectangle.bottomthird.inset.filled")
            }
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
        let appTabs = tabs.map { AppTabBar.Tab(title: $0.title, icon: $0.systemImage, id: $0.id) }
        let selectedTab = Binding(
            get: { activeTabId ?? tabs.first?.id ?? "" },
            set: { activeTabId = $0 }
        )

        return ViewThatFits(in: .horizontal) {
            tabBarRow(tabs: appTabs, selectedTab: selectedTab, showText: true)
            tabBarRow(tabs: appTabs, selectedTab: selectedTab, showText: false)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(themeVM.activeChromeTheme.workspaceTertiaryTextColor().opacity(0.05))
    }

    private func tabBarRow(
        tabs: [AppTabBar.Tab],
        selectedTab: Binding<String>,
        showText: Bool
    ) -> some View {
        HStack(spacing: 8) {
            AppTabBar(tabs: tabs, selectedTab: selectedTab, showText: showText)
            Spacer(minLength: 0)
        }
    }
}
