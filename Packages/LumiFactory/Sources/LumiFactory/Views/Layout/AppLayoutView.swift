import LumiCoreLayout
import LumiCorePanelChrome
import LumiKernel
import LumiUI
import SwiftUI

/// 新版应用主布局
///
/// 基于 `LumiKernel` 构建，通过 `WorkspaceStateProviding` 读取工作区可见性。
/// View 层只读 kernel，**不知道**是哪个插件控制了哪些能力。
struct AppLayoutView: View {
    @LumiTheme private var theme
    @ObservedObject var kernel: LumiKernel

    init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    var body: some View {
        let containers = kernel.viewContainer?.allViewContainers ?? []
        let workspace = kernel.workspaceState
        let activeID = workspace?.activeContainerID
            ?? kernel.layout?.state.activeSectionID
            ?? containers.first?.id
            ?? "main"
        let selected = containers.first { $0.id == activeID }
            ?? containers.first { $0.makeView != nil }

        let layoutState = kernel.layout?.state ?? LayoutStateInfo()
        let chatView = ChatView(
            layoutState: layoutState,
            kernel: kernel,
            chatSection: .narrow,
            activeID: activeID,
            isRailOnlyPanel: false
        )

        let railTabs = kernel.panel?.allPanelRailTabItems ?? []
        let isRailVisible = workspace?.isRailVisible ?? true
        let isChatVisible = workspace?.isChatVisible ?? true
        let isContentVisible = workspace?.isContentVisible ?? true
        let isActivityBarVisible = workspace?.isActivityBarVisible ?? true

        VStack(spacing: 0) {
            AppTitleToolbar(kernel: kernel)
            AppDivider()

            HStack(spacing: 0) {
                if isActivityBarVisible {
                    ActivityBar(kernel: kernel, containers: containers)
                    AppDivider(.vertical)
                }

                workspaceContent(
                    selected: selected,
                    chatView: chatView,
                    railTabs: railTabs,
                    isRailVisible: isRailVisible,
                    isChatVisible: isChatVisible,
                    isContentVisible: isContentVisible
                )

                ChatSectionToolbarSync(items: chatView.toolbarItems)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            AppDivider()
            StatusBar(kernel: kernel)
        }
        .frame(minWidth: 1180, minHeight: 560)
        .background(theme.background)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func workspaceContent(
        selected: ViewContainerItem?,
        chatView: ChatView,
        railTabs: [PanelRailTabItem],
        isRailVisible: Bool,
        isChatVisible: Bool,
        isContentVisible: Bool
    ) -> some View {
        // 收集需要展示的面板
        let showContent = isContentVisible && selected?.makeView != nil
        let showRail = isRailVisible && !railTabs.isEmpty
        let showChat = isChatVisible

        if showContent && (showRail || showChat) {
            HSplitView {
                if showRail {
                    SimpleRailView(tabs: railTabs)
                        .frame(minWidth: 200, maxWidth: 300)
                }
                if showContent, let makeView = selected?.makeView {
                    makeView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if showChat {
                    chatView.privacySensitive()
                }
            }
        } else {
            // 单一内容，无 split
            HStack(spacing: 0) {
                if showRail {
                    SimpleRailView(tabs: railTabs)
                        .frame(minWidth: 200, maxWidth: 300)
                }
                if showContent, let makeView = selected?.makeView {
                    makeView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if showChat {
                    chatView.privacySensitive()
                }
            }
        }
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

            if tabs.count > 0 {
                Divider()
            }

            // Active tab content
            let activeTabID = layoutState.activeRailTabID
            if let tab = tabs.first(where: { $0.id == activeTabID }) {
                tab.makeView()
            } else if let firstTab = tabs.first {
                firstTab.makeView()
            } else {
                Text("No rail tabs")
                    .font(.caption)
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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