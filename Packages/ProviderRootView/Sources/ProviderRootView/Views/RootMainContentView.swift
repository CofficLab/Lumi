import SwiftUI
import LumiUI
import ProviderWorkspace

/// 根布局内容区（可选带右侧 trailing pane）。
///
/// 逻辑来自旧版 `AppLayoutView`：
/// - 当 trailing pane 可见时，右侧显示面板（macOS 用 `HSplitView`
///   + `appSplitDivider(.trailing)`，拖拽后通过 workspace 同步宽度）；
/// - 否则只渲染主内容。
///
    /// 当主内容、content header 与 content footer 均未注入时（如 ChatPanel，激活时
    /// `contentView` 被置 nil），跳过主内容区及占位视图，让 trailing pane 独占整个内容区。
@MainActor
struct RootMainContentView: View {
    let contentHeaderView: AnyView?
    let isContentHeaderViewHidden: Bool
    let contentView: AnyView?
    let contentFooterView: AnyView?
    let isContentViewHidden: Bool
    @ObservedObject var trailingPane: RootTrailingPane
    let trailingWidth: CGFloat
    let containerID: String
    let workspace: (any WorkspaceProviding)?

    init(
        contentHeaderView: AnyView?,
        isContentHeaderViewHidden: Bool,
        contentView: AnyView?,
        contentFooterView: AnyView?,
        isContentViewHidden: Bool,
        trailingPane: RootTrailingPane?,
        trailingWidth: CGFloat,
        containerID: String,
        workspace: (any WorkspaceProviding)?
    ) {
        self.contentHeaderView = contentHeaderView
        self.isContentHeaderViewHidden = isContentHeaderViewHidden
        self.contentView = contentView
        self.contentFooterView = contentFooterView
        self.isContentViewHidden = isContentViewHidden
        self.trailingWidth = trailingWidth
        self.containerID = containerID
        self.workspace = workspace
        _trailingPane = ObservedObject(wrappedValue: trailingPane ?? RootTrailingPane(
            id: "root.empty",
            isVisible: false,
            content: AnyView(EmptyView())
        ))
    }

    private var mainContent: AnyView {
        contentView ?? AnyView(ContentPlaceholderView())
    }

    @ViewBuilder
    private var contentWithHeaderAndFooter: some View {
        if (contentHeaderView != nil && !isContentHeaderViewHidden) || contentFooterView != nil {
            VStack(spacing: 0) {
                if let contentHeaderView, !isContentHeaderViewHidden {
                    contentHeaderView
                        .zIndex(1)
                }
                mainContent
                    // AppKit-backed editors can draw floating subviews (for example,
                    // the line-number gutter) outside their SwiftUI layout bounds.
                    // Keep those subviews below the fixed content header while scrolling.
                    .clipped()
                if let contentFooterView {
                    contentFooterView
                        .zIndex(1)
                }
            }
        } else {
            mainContent
        }
    }

    /// 是否存在有意义的主内容（header 或 content 任一被注入）。
    ///
    /// 当入口不需要独立的主内容区时（如 ChatPanel，激活时 `contentView` 被置 nil），
    /// 三个插槽均为 nil，布局层据此跳过主内容区，让 trailing pane 独占。
    private var hasMainContent: Bool {
        (contentHeaderView != nil && !isContentHeaderViewHidden) || contentView != nil || contentFooterView != nil
    }

    var body: some View {
        Group {
            if isContentViewHidden {
                // 主内容区被完全隐藏（如 ChatPanel 调用 setContentViewHidden(true)）：
                // 不渲染内容区，trailing pane 独占全部空间。
                if trailingPane.isVisible {
                    trailingPane.content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if trailingPane.isVisible {
                if hasMainContent {
                    // 有主内容：主内容 + trailing pane 并排
                    #if os(macOS)
                    HSplitView {
                        contentWithHeaderAndFooter
                            .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
                            // 与旧版 AppLayoutView 一致：内容区 pane 的右侧分割线样式 + 拖拽后同步宽度。
                            .appSplitDivider(.trailing, initialPosition: trailingWidth) { position in
                                workspace?.setChatDivider(position, for: containerID, layout: .narrow)
                            }
                        trailingPane.content
                            .frame(
                                minWidth: trailingPane.minWidth,
                                idealWidth: trailingWidth,
                                maxWidth: trailingPane.maxWidth,
                                maxHeight: .infinity
                            )
                    }
                    // 与旧版 AppLayoutView 一致：切换容器时保留 Chat 分割状态。
                    .id("host.chat.\(containerID)")
                    #else
                    HStack(spacing: 0) {
                        contentWithHeaderAndFooter
                        Divider()
                        trailingPane.content
                            .frame(minWidth: trailingPane.minWidth, idealWidth: trailingPane.idealWidth)
                    }
                    #endif
                } else {
                    // 无主内容（contentView 为 nil）：trailing pane 独占，不渲染占位视图
                    trailingPane.content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                contentWithHeaderAndFooter
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
