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
                Divider()
            }

            HStack(spacing: 0) {
                if let activityBarView = provider.activityBarView {
                    activityBarView
                    Divider()
                }

                if let railView = provider.railView {
                    railView
                }

                RootMainContentView(
                    contentView: provider.contentView,
                    trailingPane: provider.trailingPane
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        #if os(macOS)
        .ignoresSafeArea()
        #endif
    }
}

@MainActor
private struct RootMainContentView: View {
    let contentView: AnyView?
    @ObservedObject var trailingPane: RootTrailingPane

    init(contentView: AnyView?, trailingPane: RootTrailingPane?) {
        self.contentView = contentView
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
            if trailingPane.isVisible {
                #if os(macOS)
                HSplitView {
                    mainContent
                        .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
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
