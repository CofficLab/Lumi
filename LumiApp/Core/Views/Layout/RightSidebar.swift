import LumiUI
import SwiftUI

/// 右侧栏容器视图
///
/// 聚合所有插件提供的右侧栏 Section 视图和底部工具栏项。
/// 上半部分使用 VStack 垂直堆叠所有 Section（如消息列表、输入区域）；
/// 底部固定渲染水平工具栏，聚合所有插件的 SidebarToolbarItem。
struct RightSidebarContainerView: View {
    @EnvironmentObject private var pluginProvider: AppPluginVM
    @EnvironmentObject private var themeVM: AppThemeVM

    /// 插件提供的右侧栏 Section 视图列表（按插件 order 升序、数组顺序排列）
    let sections: [AnyView]

    var body: some View {
        guard !sections.isEmpty else {
            return AnyView(Color.clear)
        }

        return pluginProvider.getRightSidebarRootWrapper(activeIcon: pluginProvider.activePanelIcon) {
            VStack(spacing: 0) {
                // ── 上半部分：Section 视图区 ──
                ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                    section

                    // 非最后一个 section 之间添加分隔线
                    if index < sections.count - 1 {
                        GlassDivider()
                    }
                }

                // ── 下半部分：底部工具栏 ──
                let toolbarItems = pluginProvider.getSidebarToolbarItems()
                if !toolbarItems.isEmpty {
                    GlassDivider()
                    SidebarToolbarBar(items: toolbarItems)
                }
            }
            .frame(maxHeight: .infinity)
            .frame(minWidth: 320, idealWidth: 400)
        }
    }
}

// MARK: - Sidebar Toolbar Bar

/// 右侧栏底部工具栏
///
/// 水平排列所有插件提供的 SidebarToolbarItem。
/// 优先使用插件自定义视图（`addSidebarToolbarItemView`），否则使用默认图标按钮。
/// 最后一个位置留空给 Spacer，保持按钮靠左对齐。
private struct SidebarToolbarBar: View {
    @EnvironmentObject private var pluginProvider: AppPluginVM
    @EnvironmentObject private var themeVM: AppThemeVM

    let items: [SidebarToolbarItem]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                toolbarButton(for: item)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
    }

    // MARK: - Button Rendering

    @ViewBuilder
    private func toolbarButton(for item: SidebarToolbarItem) -> some View {
        // 优先使用插件提供的自定义视图
        if let customView = pluginProvider.getSidebarToolbarItemView(itemId: item.id) {
            customView
                .help(item.title)
                .accessibilityLabel(item.title)
        } else {
            // 默认图标按钮
            Button(action: {}) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 13))
                    .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                    .frame(width: 28, height: 28)
                    .background(themeVM.activeAppTheme.workspaceTextColor().opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(item.title)
            .accessibilityLabel(item.title)
        }
    }
}

// MARK: - Preview

#Preview("Single Section") {
    RightSidebarContainerView(sections: [
        AnyView(Text("Messages").frame(maxWidth: .infinity, maxHeight: .infinity))
    ])
    .inRootView()
    .frame(height: 400)
}

#Preview("Multiple Sections") {
    RightSidebarContainerView(sections: [
        AnyView(Text("Messages").frame(maxWidth: .infinity, maxHeight: .infinity)),
        AnyView(Text("Input Area").frame(maxWidth: .infinity).padding(8)),
    ])
    .inRootView()
    .frame(height: 400)
}
