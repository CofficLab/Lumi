import SwiftUI
import LumiUI
import ProviderRootView

@MainActor
struct WorkbenchSplitView: View {
    @ObservedObject var provider: LumiRootViewProvider
    @LumiTheme private var theme

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
                        .debugViewBadge("Rail", alignment: .bottomTrailing)
                        .appSplitDivider(
                            .trailing,
                            initialPosition: provider.railWidth.idealWidth,
                            // Rail 右侧平时不留阴影，避免与 Rail 内面板栏自带的
                            // 底部边框/阴影叠成两层视觉边；hover 时才浮现。
                            restingShadow: false,
                            onResize: provider.saveRailViewWidth
                        )
                        // Rail 右侧自绘 1pt 分隔线，与左侧 ActivityBar 的 1pt 分隔线
                        // 视觉权重对齐。`appSplitDivider` 自带的分隔线只有 0.5pt，
                        // 在 1x 屏上几乎不可见，会让 Rail 左右两侧看起来不对称。
                        // 两处 overlay 作用于同一个 `.frame(...)` 结果，trailing 边完全重合。
                        .overlay(alignment: .trailing) {
                            Rectangle()
                                .fill(theme.divider)
                                .frame(width: 1)
                        }
                    provider.hasActiveContent ? AnyView(mainContent) : AnyView(RootWelcomeView())
                }
                // Rail 首批标签是**动态**注册的（`chats` 要等会话数据首次加载完成）。
                // 首帧时 Rail 面板还没有任何标签，`HSplitView` 会把这一侧折叠成 0 宽，
                // 之后标签注册成功也不会自动展开 —— 表现为「会话存在但列表永远不可见」。
                // 内容从无到有时重建整个 split 视图，让它以 `idealWidth` 重新布局。
                .id(provider.hasRailContent)
                #else
                HStack(spacing: 0) {
                    provider.railView!
                        .debugViewBadge("Rail", alignment: .bottomTrailing)
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
            isContentFooterViewHidden: provider.isContentFooterViewHidden,
            contentFooterHeight: provider.contentFooterHeight,
            onContentFooterResize: provider.saveCurrentContentFooterHeight,
            isContentViewHidden: provider.isContentViewHidden,
            trailingPane: provider.trailingPane
        )
    }
}
