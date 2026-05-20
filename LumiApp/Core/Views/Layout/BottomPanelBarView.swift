import MagicAlert
import LumiUI
import SwiftUI

/// 全局底部面板视图
///
/// 由内核统一维护，聚合所有插件提供的 `BottomPanelTab`，
/// 渲染统一的 Tab 栏 + 内容切换器。各插件只需提供 Tab 入口
/// （图标 + 标题 + 内容视图），无需关心 Tab 栏的渲染和切换逻辑。
struct BottomPanelBarView: View {
    @LumiMotionPreferenceReader private var motionPreference
    @EnvironmentObject private var pluginProvider: AppPluginVM
    @EnvironmentObject private var themeVM: AppThemeVM

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
                    .transition(.opacity.animation(LumiMotion.enabled(LumiMotion.reveal, preference: motionPreference)))
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
        // 监听自动化测试请求切换底部面板 Tab
        .onReceive(NotificationCenter.default.publisher(for: .automationActivateBottomTab)) { notification in
            guard let tabId = notification.userInfo?["tabId"] as? String else { return }
            if tabs.contains(where: { $0.id == tabId }) {
                activeTabId = tabId
                let tabTitle = tabs.first(where: { $0.id == tabId })?.title ?? tabId
                alert_info("自动化测试：切换底部面板「\(tabTitle)」")
            }
        }
    }

    // MARK: - Tab Bar

    private func tabBar(tabs: [BottomPanelTab]) -> some View {
        HStack(spacing: 8) {
            ForEach(tabs) { tab in
                BottomPanelTabButton(
                    tab: tab,
                    isActive: activeTabId == tab.id,
                    action: { activeTabId = tab.id }
                )
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.05))
    }
}

// MARK: - Tab Button with Hover

/// 底部面板的单个标签按钮，支持 hover 高亮效果
private struct BottomPanelTabButton: View {
    @LumiMotionPreferenceReader private var motionPreference
    @EnvironmentObject private var themeVM: AppThemeVM

    let tab: BottomPanelTab
    let isActive: Bool
    let action: () -> Void

    /// 当前是否处于 hover 状态
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 10, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 11, weight: isActive ? .semibold : .medium))
            }
            .foregroundColor(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(backgroundColor)
            )
            .contentShape(RoundedRectangle(cornerRadius: 7))
            .scaleEffect(isHovering && !isActive && motionPreference.allowsMotion ? LumiMotion.hoverScale : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            LumiMotion.animate(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference)) {
                isHovering = hovering
            }
        }
        // hover / 选中状态变化时平滑过渡
        .animation(LumiMotion.enabled(LumiMotion.selection, preference: motionPreference), value: isActive)
        .animation(LumiMotion.enabled(LumiMotion.hover, preference: motionPreference), value: isHovering)
    }

    // MARK: - Computed Colors

    /// 文字颜色：选中态 > hover 态 > 默认态
    private var textColor: Color {
        if isActive {
            return themeVM.activeAppTheme.workspaceTextColor()
        } else if isHovering {
            return themeVM.activeAppTheme.workspaceTextColor().opacity(0.85)
        } else {
            return themeVM.activeAppTheme.workspaceSecondaryTextColor()
        }
    }

    /// 背景颜色：选中态 > hover 态 > 默认透明
    private var backgroundColor: Color {
        if isActive {
            return themeVM.activeAppTheme.workspaceTextColor().opacity(0.08)
        } else if isHovering {
            return themeVM.activeAppTheme.workspaceTextColor().opacity(0.05)
        } else {
            return Color.clear
        }
    }
}
