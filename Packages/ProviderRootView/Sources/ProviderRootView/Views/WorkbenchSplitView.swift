import SwiftUI
import LumiUI
import ProviderWorkspace

@MainActor
struct WorkbenchSplitView: View {
    @ObservedObject var provider: DefaultRootViewProvider

    private var workspace: (any WorkspaceProviding)? { provider.workspaceProvider }
    private var containerID: String { provider.containerID }
    private var showsRail: Bool {
        provider.railView != nil
    }

    var body: some View {
        Group {
            if showsRail {
                #if os(macOS)
                HSplitView {
                    provider.railView!
                        .frame(minWidth: 180, idealWidth: workspace?.railDivider(for: containerID, fallback: 240) ?? 240, maxWidth: 400)
                        // 与旧版 AppLayoutView 一致：Rail pane 的右侧分割线样式 + 拖拽后同步宽度。
                        .appSplitDivider(.trailing, initialPosition: workspace?.railDivider(for: containerID, fallback: 240) ?? 240) { position in
                            workspace?.setRailDivider(position, for: containerID)
                        }
                    provider.hasActiveContent ? AnyView(mainContent) : AnyView(RootWelcomeView())
                }
                .id("host.rail.\(containerID)")
                #else
                HStack(spacing: 0) {
                    provider.railView!
                    Divider()
                    provider.hasActiveContent ? AnyView(mainContent) : AnyView(RootWelcomeView())
                }
                #endif
            } else if provider.hasActiveContent {
                mainContent
            } else {
                // 与旧版 AppLayoutView 一致：无活跃内容时显示欢迎占位。
                RootWelcomeView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mainContent: some View {
        RootMainContentView(
            contentHeaderView: provider.contentHeaderView,
            isContentHeaderViewHidden: provider.isContentHeaderViewHidden,
            contentView: provider.contentView,
            contentFooterView: provider.contentFooterView,
            isContentViewHidden: provider.isContentViewHidden,
            trailingPane: provider.trailingPane,
            trailingWidth: workspace?.chatDivider(for: containerID, layout: .narrow, fallback: 320) ?? 320,
            containerID: containerID,
            workspace: workspace
        )
    }
}
