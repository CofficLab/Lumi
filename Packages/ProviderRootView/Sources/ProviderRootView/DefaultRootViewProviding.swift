import Combine
import LumiUI
import ProviderWorkspace
import SwiftUI

/// `RootViewProviding` 的默认实现：持有注入的工具栏、ActivityBar、Rail
/// 与主内容视图，组合成「顶部工具栏 + 内容区（左侧 ActivityBar，右侧 Rail）」
/// 的根布局（模仿 AppLayoutView 结构）。
///
/// 主内容未注入时显示居中占位提示；注入后（通常来自 `ContentViewProviding`）
/// 显示为内容区。
@MainActor
public final class DefaultRootViewProviding: RootViewProviding, ObservableObject {
    @Published fileprivate var toolbarView: AnyView?
    @Published fileprivate var activityBarView: AnyView?
    @Published fileprivate var railView: AnyView?
    @Published fileprivate var contentView: AnyView?
    @Published fileprivate var trailingPane: RootTrailingPane?
    fileprivate var workspaceProvider: (any WorkspaceProviding)?
    private var workspaceSubscription: AnyCancellable?

    public init() {}

    public func setToolbarView(_ view: AnyView?) {
        toolbarView = view
    }

    public func setActivityBarView(_ view: AnyView?) {
        activityBarView = view
    }

    public func setRailView(_ view: AnyView?) {
        railView = view
    }

    public func setContentView(_ view: AnyView?) {
        contentView = view
    }

    public func setTrailingPane(_ pane: RootTrailingPane?) {
        trailingPane = pane
    }

    public func setWorkspaceProvider(_ provider: (any WorkspaceProviding)?) {
        workspaceProvider = provider
        workspaceSubscription = provider?.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        objectWillChange.send()
    }

    public func makeRootView() -> AnyView {
        AnyView(DefaultRootHostView(provider: self))
    }
}

@MainActor
private struct DefaultRootHostView: View {
    @ObservedObject var provider: DefaultRootViewProviding

    var body: some View {
        VStack(spacing: 0) {
            if let toolbarView = provider.toolbarView {
                toolbarView
                // 与旧版 AppLayoutView 一致：工具栏下方使用主题分隔线。
                AppDivider()
            }

            HStack(spacing: 0) {
                if let activityBarView = provider.activityBarView {
                    activityBarView
                    // 与旧版 AppLayoutView 一致：ActivityBar 右侧使用主题竖向分隔线。
                    AppDivider(.vertical)
                }

                WorkbenchSplitView(provider: provider)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        #if os(macOS)
        .ignoresSafeArea()
        #endif
    }
}

@MainActor
private struct WorkbenchSplitView: View {
    @ObservedObject var provider: DefaultRootViewProviding

    private var workspace: (any WorkspaceProviding)? { provider.workspaceProvider }
    private var containerID: String { workspace?.activeContainerID ?? "root" }
    private var showsRail: Bool { provider.railView != nil && (workspace?.isRailVisible ?? true) }

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
                    mainContent
                }
                .id("host.rail.\(containerID)")
                #else
                HStack(spacing: 0) { provider.railView!; Divider(); mainContent }
                #endif
            } else {
                mainContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mainContent: some View {
        RootMainContentView(
            contentView: provider.contentView,
            trailingPane: provider.trailingPane,
            workspaceShowsTrailingPane: workspace?.isChatVisible ?? true,
            trailingWidth: workspace?.chatDivider(for: containerID, layout: .narrow, fallback: 320) ?? 320,
            containerID: containerID,
            workspace: workspace
        )
    }
}

@MainActor
private struct RootMainContentView: View {
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

/// 内容区占位视图。
private struct ContentPlaceholderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "macwindow")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Root View")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
