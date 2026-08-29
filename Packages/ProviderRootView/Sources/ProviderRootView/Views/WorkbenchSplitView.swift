import SwiftUI
import LumiUI

@MainActor
struct WorkbenchSplitView: View {
    @ObservedObject var provider: DefaultRootViewProvider

    private var showsRail: Bool {
        provider.railView != nil
    }

    var body: some View {
        Group {
            if showsRail {
                #if os(macOS)
                HSplitView {
                    provider.railView!
                        .frame(minWidth: 180, idealWidth: 240, maxWidth: 400)
                        .appSplitDivider(.trailing, initialPosition: 240, onResize: nil)
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
            trailingPane: provider.trailingPane,
            trailingWidth: 320
        )
    }
}
