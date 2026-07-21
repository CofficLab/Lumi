import LumiCoreLayout
import LumiCorePanelChrome
import LumiKernel
import LumiUI
import SwiftUI

/// 新版应用主布局
///
/// 基于 `LumiKernel` 构建，消费插件注册的视图容器。右侧始终展示 Chat 区域，
/// 支持插件通过 `kernel.registerChatSectionItem` 注入 Chat UI。
struct AppLayoutView: View {
    @LumiTheme private var theme
    @ObservedObject var kernel: LumiKernel

    init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    /// 当前布局服务提供的激活分区信息。
    private var layoutInfo: LayoutStateInfo {
        kernel.layout?.state ?? LayoutStateInfo()
    }

    var body: some View {
        let containers = kernel.viewContainer?.allViewContainers ?? []
        let selected = selectedContainer(from: containers)

        let activeID = selected?.id ?? "main"
        let chatSection = selected?.chatSection ?? .narrow
        let showsRail = selected?.showsRail ?? false
        let layoutState = kernel.layout?.state ?? LayoutStateInfo()
        let chatView = ChatView(
            layoutState: layoutState,
            kernel: kernel,
            chatSection: .narrow,  // 始终显示 chat
            activeID: activeID,
            isRailOnlyPanel: false
        )

        // Get rail tabs
        let railTabs = kernel.panel?.allPanelRailTabItems ?? []
        let showRail = showsRail && !railTabs.isEmpty

        VStack(spacing: 0) {
            AppTitleToolbar(kernel: kernel)

            AppDivider()

            HStack(spacing: 0) {
                ActivityBar(
                    kernel: kernel,
                    containers: containers
                )

                AppDivider(.vertical)

                if showRail {
                    // Rail view + panel content
                    HSplitView {
                        SimpleRailView(tabs: railTabs)
                            .frame(minWidth: 200, maxWidth: 300)

                        if let selected, let makeView = selected.makeView {
                            makeView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            emptyState
                        }
                        
                        chatView.privacySensitive()
                    }
                } else {
                    HSplitView {
                        if let selected, let makeView = selected.makeView {
                            makeView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            emptyState
                        }

                        // 始终显示 ChatView（忽略 chatSection.isVisible）
                        chatView.privacySensitive()
                    }
                }

                ChatSectionToolbarSync(
                    items: chatView.toolbarItems
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            AppDivider()

            StatusBar(kernel: kernel)
        }
        .frame(minWidth: 1180, minHeight: 560)
        .background(theme.background)
        .ignoresSafeArea()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cube.box")
                .font(.system(size: 48))
                .foregroundStyle(theme.textTertiary)

            Text("没有可用的视图容器")
                .font(.appBodyEmphasized)
                .foregroundStyle(theme.textSecondary)

            Text("请启用至少一个提供视图容器的插件")
                .font(.appCaption)
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func selectedContainer(from containers: [ViewContainerItem]) -> ViewContainerItem? {
        let activeID = layoutInfo.activeSectionID
        if !activeID.isEmpty,
           let container = containers.first(where: { $0.id == activeID }) {
            return container
        }
        return containers.first
    }
}

// MARK: - Simple Rail View

/// 简化版 Rail 视图，仅显示 rail tabs
struct SimpleRailView: View {
    let tabs: [PanelRailTabItem]

    @LumiTheme private var theme
    @ObservedObject private var layoutState = LayoutState()

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            if tabs.count > 1 {
                ForEach(tabs) { tab in
                    railTabButton(tab)
                }
            }

            Divider()

            // Active tab content
            let activeTabID = layoutState.activeRailTabID
            if let tab = tabs.first(where: { $0.id == activeTabID }) {
                tab.makeView()
            } else if let firstTab = tabs.first {
                firstTab.makeView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.surface)
    }

    private func railTabButton(_ tab: PanelRailTabItem) -> some View {
        let isSelected = layoutState.activeRailTabID == tab.id
        return Button {
            layoutState.activeRailTabID = tab.id
        } label: {
            HStack {
                Image(systemName: tab.systemImage)
                    .frame(width: 20)
                Text(tab.title)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? theme.primary.opacity(0.1) : Color.clear)
            .foregroundColor(isSelected ? theme.primary : theme.textSecondary)
        }
        .buttonStyle(.plain)
    }
}
