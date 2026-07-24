import LumiKernel
import LumiUI
import SwiftUI

/// 新版应用主布局
///
/// 基于 `LumiKernel` 构建，通过 LayoutProviding 读取工作区可见性。
/// View 层只读 kernel，**不知道**是哪个插件控制了哪些能力。
struct AppLayoutView: View {
    @LumiTheme private var theme
    @ObservedObject var kernel: LumiKernel

    init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    var body: some View {
        let containers = kernel.viewContainer?.allViewContainers ?? []
        let layoutState = kernel.layout?.layoutState
        let activeID = layoutState?.activeViewContainerID
            ?? kernel.layout?.state.activeSectionID
            ?? containers.first?.id
            ?? "main"
        let selected = containers.first { $0.id == activeID }
            ?? containers.first { $0.makeView != nil }

        let chatView = ChatView(kernel: kernel)

        let railTabs = kernel.panel?.allPanelRailTabItems ?? []
        let isRailVisible = layoutState?.isRailVisible ?? true
        let isChatVisible = layoutState?.isChatVisible ?? true
        let isContentVisible = layoutState?.isContentVisible ?? true
        let isActivityBarVisible = layoutState?.isActivityBarVisible ?? true

        VStack(spacing: 0) {
            AppTitleToolbar(kernel: kernel)
            AppDivider()

            HStack(spacing: 0) {
                if isActivityBarVisible {
                    ActivityBar(kernel: kernel)
                    AppDivider(.vertical)
                }

                workspaceContent(
                    selected: selected,
                    chatView: chatView,
                    railTabs: railTabs,
                    isRailVisible: isRailVisible,
                    isChatVisible: isChatVisible,
                    isContentVisible: isContentVisible,
                    layoutState: layoutState ?? LayoutState()
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

    @ViewBuilder
    private func workspaceContent(
        selected: ViewContainerItem?,
        chatView: ChatView,
        railTabs: [PanelRailTabItem],
        isRailVisible: Bool,
        isChatVisible: Bool,
        isContentVisible: Bool,
        layoutState: LayoutState
    ) -> some View {
        // 收集需要展示的面板
        let showContent = isContentVisible && selected?.makeView != nil
        let showRail = isRailVisible && !railTabs.isEmpty
        let showChat = isChatVisible

        if showContent && (showRail || showChat) {
            HSplitView {
                if showRail {
                    SimpleRailView(tabs: railTabs, layoutState: layoutState)
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
                    SimpleRailView(tabs: railTabs, layoutState: layoutState)
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
