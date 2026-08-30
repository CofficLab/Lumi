import SwiftUI
import LumiUI

@MainActor
struct WorkbenchSplitView: View {
    @ObservedObject var provider: DefaultRootViewProvider

    private var showsRail: Bool {
        provider.railView != nil && provider.isRailViewVisible
    }

    var body: some View {
        Group {
            if showsRail {
                #if os(macOS)
                HSplitView {
                    provider.railView!
                        .frame(
                            minWidth: provider.railWidth.minWidth,
                            idealWidth: provider.railWidth.idealWidth,
                            maxWidth: provider.railWidth.maxWidth
                        )
                        .appSplitDivider(
                            .trailing,
                            initialPosition: provider.railWidth.idealWidth,
                            onResize: provider.saveRailViewWidth
                        )
                    provider.hasActiveContent ? AnyView(mainContent) : AnyView(RootWelcomeView())
                }
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
            trailingPane: provider.trailingPane
        )
    }
}
