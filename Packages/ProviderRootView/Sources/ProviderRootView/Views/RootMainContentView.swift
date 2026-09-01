import SwiftUI
import LumiUI

/// 根布局内容区（可选带右侧 trailing pane）。
///
/// 逻辑来自旧版 `AppLayoutView`：
/// - 当 trailing pane 可见时，右侧显示面板（macOS 用 `HSplitView`
///   + `appSplitDivider(.trailing)`）；
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
    let contentFooterHeight: ContentFooterHeight
    let onContentFooterResize: (@MainActor (CGFloat) -> Void)?
    let isContentViewHidden: Bool
    @ObservedObject var trailingPane: RootTrailingPane
    init(
        contentHeaderView: AnyView?,
        isContentHeaderViewHidden: Bool,
        contentView: AnyView?,
        contentFooterView: AnyView?,
        contentFooterHeight: ContentFooterHeight = .standard,
        onContentFooterResize: (@MainActor (CGFloat) -> Void)? = nil,
        isContentViewHidden: Bool,
        trailingPane: RootTrailingPane?
    ) {
        self.contentHeaderView = contentHeaderView
        self.isContentHeaderViewHidden = isContentHeaderViewHidden
        self.contentView = contentView
        self.contentFooterView = contentFooterView
        self.contentFooterHeight = contentFooterHeight
        self.onContentFooterResize = onContentFooterResize
        self.isContentViewHidden = isContentViewHidden
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
        if let contentFooterView {
            #if os(macOS)
            VSplitView {
                contentWithHeader
                    .frame(minHeight: 0, maxHeight: .infinity)
                    .appSplitDivider(
                        .bottom,
                        initialTrailingSize: contentFooterHeight.idealHeight,
                        resizeTarget: .trailing,
                        onResize: onContentFooterResize
                    )
                contentFooterView
                    .frame(
                        minHeight: contentFooterHeight.minHeight,
                        idealHeight: contentFooterHeight.idealHeight,
                        maxHeight: contentFooterHeight.maxHeight
                    )
                    .zIndex(1)
            }
            #else
            VStack(spacing: 0) {
                contentWithHeader
                contentFooterView
            }
            #endif
        } else if contentHeaderView != nil && !isContentHeaderViewHidden {
            contentWithHeader
        } else {
            mainContent
        }
    }

    @ViewBuilder
    private var contentWithHeader: some View {
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
                            .appSplitDivider(
                                .trailing,
                                initialPosition: trailingPane.width.idealWidth,
                                onResize: trailingPane.saveWidth
                            )
                        trailingPane.content
                            .frame(
                                minWidth: trailingPane.minWidth,
                                idealWidth: trailingPane.idealWidth,
                                maxWidth: trailingPane.maxWidth,
                                maxHeight: .infinity
                            )
                    }
                    #else
                    HStack(spacing: 0) {
                        contentWithHeaderAndFooter
                        Divider()
                        trailingPane.content
                            .frame(minWidth: trailingPane.minWidth, idealWidth: trailingPane.idealWidth, maxWidth: trailingPane.maxWidth)
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
