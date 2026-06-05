import LumiCoreKit
import LumiUI
import SwiftUI

/// 右侧栏容器视图
///
/// 聚合所有插件提供的右侧栏 Section 视图和底部工具栏项。
/// 上半部分使用 VStack 垂直堆叠所有 Section（如消息列表、输入区域）；
/// 底部固定渲染水平工具栏，聚合所有插件的 leading/trailing SidebarToolbarItem。
struct RightSidebarContainerView: View {
    @EnvironmentObject private var pluginProvider: AppPluginVM
    @EnvironmentObject private var layoutVM: WindowLayoutVM
    @EnvironmentObject private var themeVM: AppThemeVM
    @EnvironmentObject private var messageRendererVM: AppMessageRendererVM
    @Environment(\.windowContainer) private var windowContainer

    /// 插件提供的右侧栏 Section 视图列表（按插件 order 升序、数组顺序排列）
    let sections: [AnyView]
    let bottomSections: [AnyView]

    var body: some View {
        guard !sections.isEmpty || !bottomSections.isEmpty else {
            return AnyView(Color.clear)
        }

        let activeIcon = layoutVM.activeViewContainerIcon
        let activeContainer = pluginProvider.getActiveViewContainer(activeIcon: activeIcon)
        let pluginContext = PluginContext(
            activeIcon: activeIcon,
            isEditorVisible: layoutVM.editorVisible,
            showChat: activeContainer?.showChat ?? false,
            showsProjectToolbar: activeContainer?.showsProjectToolbar ?? false,
            showsRail: activeContainer?.showsRail ?? false,
            showsBottomPanel: activeContainer?.showsBottomPanel ?? false,
            windowId: windowContainer?.id,
            messageRenderer: renderMessage
        )

        return pluginProvider.getRightSidebarRootWrapper(context: pluginContext) {
            VStack(spacing: 0) {
                // ── 上半部分：Section 视图区 ──
                ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                    section

                    // 非最后一个 section 之间添加分隔线
                    if index < sections.count - 1 {
                        GlassDivider()
                    }
                }

                if !bottomSections.isEmpty {
                    if !sections.isEmpty {
                        GlassDivider()
                    }

                    ForEach(Array(bottomSections.enumerated()), id: \.offset) { index, section in
                        section

                        if index < bottomSections.count - 1 {
                            GlassDivider()
                        }
                    }
                }

                // ── 下半部分：底部工具栏 ──
                let leadingToolbarItems = pluginProvider.getSidebarLeadingToolbarItems(context: pluginContext)
                let trailingToolbarItems = pluginProvider.getSidebarTrailingToolbarItems(context: pluginContext)
                if !leadingToolbarItems.isEmpty || !trailingToolbarItems.isEmpty {
                    GlassDivider()
                    SidebarToolbarBar(
                        leadingItems: leadingToolbarItems,
                        trailingItems: trailingToolbarItems
                    )
                }
            }
            .frame(maxHeight: .infinity)
            .frame(minWidth: 320, idealWidth: 400)
        }
    }

    private func renderMessage(_ message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView? {
        guard let renderer = messageRendererVM.findRenderer(for: message) else {
            return nil
        }
        return renderer.render(message: message, showRawMessage: showRawMessage)
    }
}

// MARK: - Sidebar Toolbar Bar

/// 右侧栏底部工具栏
///
/// 水平排列所有插件提供的 leading/trailing SidebarToolbarItem。
/// 优先使用插件自定义视图（`addSidebarToolbarItemView`），否则使用非交互图标占位。
private struct SidebarToolbarBar: View {
    @EnvironmentObject private var pluginProvider: AppPluginVM
    @EnvironmentObject private var layoutVM: WindowLayoutVM
    @EnvironmentObject private var themeVM: AppThemeVM
    @EnvironmentObject private var messageRendererVM: AppMessageRendererVM
    @Environment(\.windowContainer) private var windowContainer

    let leadingItems: [SidebarToolbarItem]
    let trailingItems: [SidebarToolbarItem]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(leadingItems) { item in
                toolbarButton(for: item)
            }

            Spacer(minLength: 0)

            ForEach(trailingItems) { item in
                toolbarButton(for: item)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(themeVM.activeChromeTheme.workspaceBackgroundColor())
    }

    // MARK: - Button Rendering

    @ViewBuilder
    private func toolbarButton(for item: SidebarToolbarItem) -> some View {
        // 优先使用插件提供的自定义视图
        let activeIcon = layoutVM.activeViewContainerIcon
        let activeContainer = pluginProvider.getActiveViewContainer(activeIcon: activeIcon)
        let toolbarContext = PluginContext(
            activeIcon: activeIcon,
            isEditorVisible: layoutVM.editorVisible,
            showChat: activeContainer?.showChat ?? false,
            showsProjectToolbar: activeContainer?.showsProjectToolbar ?? false,
            showsRail: activeContainer?.showsRail ?? false,
            showsBottomPanel: activeContainer?.showsBottomPanel ?? false,
            windowId: windowContainer?.id,
            messageRenderer: renderMessage
        )
        if let customView = pluginProvider.getSidebarToolbarItemView(itemId: item.id, context: toolbarContext) {
            customView
                .help(item.title)
                .accessibilityLabel(item.title)
        } else {
            Image(systemName: item.systemImage)
                .font(.appCallout)
                .foregroundColor(themeVM.activeChromeTheme.workspaceSecondaryTextColor())
                .frame(width: 28, height: 28)
                .background(themeVM.activeChromeTheme.workspaceTextColor().opacity(0.06))
                .clipShape(Circle())
                .opacity(0.55)
            .help(item.title)
            .accessibilityLabel(item.title)
        }
    }

    private func renderMessage(_ message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView? {
        guard let renderer = messageRendererVM.findRenderer(for: message) else {
            return nil
        }
        return renderer.render(message: message, showRawMessage: showRawMessage)
    }
}

// MARK: - Preview

#Preview("Single Section") {
    RightSidebarContainerView(sections: [
        AnyView(Text("Messages").frame(maxWidth: .infinity, maxHeight: .infinity))
    ], bottomSections: [])
    .inRootView()
    .frame(height: 400)
}

#Preview("Multiple Sections") {
    RightSidebarContainerView(sections: [
        AnyView(Text("Messages").frame(maxWidth: .infinity, maxHeight: .infinity)),
    ], bottomSections: [
        AnyView(Text("Input Area").frame(maxWidth: .infinity).padding(8)),
    ])
    .inRootView()
    .frame(height: 400)
}
