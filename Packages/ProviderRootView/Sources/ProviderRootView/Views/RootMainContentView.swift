import SwiftUI
import LumiUI
import ProviderWorkspace

/// 根布局内容区（可选带右侧 trailing pane）。
///
/// 逻辑来自旧版 `AppLayoutView`：
/// - 当 trailing pane 可见且 workspace 允许时，右侧显示面板（macOS 用 `HSplitView`
///   + `appSplitDivider(.trailing)`，拖拽后通过 workspace 同步宽度）；
/// - 否则只渲染主内容。
///
/// 主内容未注入时回退到 `ContentPlaceholderView`。
@MainActor
struct RootMainContentView: View {
    let contentView: AnyView?
    @ObservedObject var trailingPane: RootTrailingPane
    let workspaceShowsTrailingPane: Bool
    let trailingWidth: CGFloat
    let containerID: String
    let workspace: (any WorkspaceProviding)?

    init(
        contentView: AnyView?,
        trailingPane: RootTrailingPane?,
        workspaceShowsTrailingPane: Bool,
        trailingWidth: CGFloat,
        containerID: String,
        workspace: (any WorkspaceProviding)?
    ) {
        self.contentView = contentView
        self.workspaceShowsTrailingPane = workspaceShowsTrailingPane
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

    var body: some View {
        Group {
            if trailingPane.isVisible && workspaceShowsTrailingPane {
                #if os(macOS)
                HSplitView {
                    mainContent
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
                    mainContent
                    Divider()
                    trailingPane.content
                        .frame(minWidth: trailingPane.minWidth, idealWidth: trailingPane.idealWidth)
                }
                #endif
            } else {
                mainContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
