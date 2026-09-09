import SwiftUI
import LumiUI
import ProviderRailView

@MainActor
struct WorkbenchSplitView: View {
    let provider: DefaultRootViewProvider
    @State private var observedRailWidth: RailViewWidth
    @State private var observationRevision = 0
    @State private var observerHandle: (any RootViewObserverHandle)?

    init(provider: DefaultRootViewProvider) {
        self.provider = provider
        _observedRailWidth = State(initialValue: provider.railWidth)
    }

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
                            minWidth: observedRailWidth.minWidth,
                            idealWidth: observedRailWidth.idealWidth,
                            maxWidth: observedRailWidth.maxWidth
                        )
                        .appSplitDivider(
                            .trailing,
                            initialPosition: observedRailWidth.idealWidth,
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
        .id(observationRevision)
        .onAppear {
            guard observerHandle == nil else { return }
            observedRailWidth = provider.railWidth
            observerHandle = provider.addRootViewObserver { event in
                switch event {
                case let .railWidthChanged(width):
                    // Width is a layout-only update. Keep the HSplitView subtree's
                    // identity stable so list tasks and scroll state are preserved.
                    observedRailWidth = width
                case .railViewChanged,
                     .railViewVisibilityChanged,
                     .contentHeaderViewChanged,
                     .contentHeaderVisibilityChanged,
                     .contentViewChanged,
                     .contentViewVisibilityChanged,
                     .contentFooterViewChanged,
                     .contentFooterVisibilityChanged,
                     .contentFooterHeightChanged,
                     .trailingPaneChanged:
                    observationRevision += 1
                default:
                    break
                }
            }
        }
        .onDisappear {
            observerHandle?.cancel()
            observerHandle = nil
        }
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
