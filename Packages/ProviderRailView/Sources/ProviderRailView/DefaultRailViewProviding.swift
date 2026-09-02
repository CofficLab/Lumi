import Combine
import LumiUI
import SwiftUI

/// `RailViewProviding` 的默认实现：持有注入的 `RailTabItem`，
/// 渲染为「顶部标签栏 + 内容区」的侧边栏（与旧版 `FactoryCore.RailView` 视觉一致）。
///
/// 点击 tab 切换选中项并展示对应内容。
@MainActor
public final class DefaultRailViewProviding: RailViewProviding, ObservableObject {
    @Published public private(set) var tabs: [RailTabItem] = []
    @Published public private(set) var visibleCategories: Set<RailViewCategory>
    @Published public private(set) var visibleTabID: String?
    @Published public private(set) var activeTabID: String?
    @Published public private(set) var hasVisibleTabs = false
    @Published public private(set) var railWidth: RailViewWidth

    private let defaultWidthStore: (any RailViewWidthStoring)?
    private var activeWidthStore: (any RailViewWidthStoring)?
    private var activeWidthOwnerID: String?

    private var observers: [WeakObserver] = []

    public var railVisibilityPublisher: AnyPublisher<Bool, Never> {
        $hasVisibleTabs.eraseToAnyPublisher()
    }

    public init(
        visibleCategories: Set<RailViewCategory> = Set(RailViewCategory.allCases),
        visibleTabID: String? = nil,
        widthStore: (any RailViewWidthStoring)? = nil
    ) {
        self.visibleCategories = visibleCategories
        self.visibleTabID = visibleTabID
        self.railWidth = .standard
        self.defaultWidthStore = widthStore
        self.activeWidthStore = nil
    }

    public func registerTabs(_ tabs: [RailTabItem]) {
        let oldTabs = self.tabs
        let oldActiveTabID = activeTabID
        let oldHasVisibleTabs = hasVisibleTabs

        self.tabs = tabs.sorted { $0.order < $1.order }
        reconcileActiveTab()
        updateVisibleTabState()

        if self.tabs.map(\.id) != oldTabs.map(\.id) {
            notify(.tabsChanged(self.tabs))
        }
        if activeTabID != oldActiveTabID {
            notify(.activeTabChanged(activeTabID))
        }
        if hasVisibleTabs != oldHasVisibleTabs {
            notify(.visibilityChanged(hasVisibleTabs))
        }
    }

    public func activateTab(id: String?) {
        let oldActiveTabID = activeTabID
        guard let id else {
            activeTabID = nil
            if activeTabID != oldActiveTabID {
                notify(.activeTabChanged(activeTabID))
            }
            return
        }
        guard visibleTabs.contains(where: { $0.id == id }) else { return }
        activeTabID = id
        if activeTabID != oldActiveTabID {
            notify(.activeTabChanged(activeTabID))
        }
    }

    public func setVisibleCategories(_ categories: Set<RailViewCategory>) {
        guard visibleCategories != categories || visibleTabID != nil else { return }
        let oldVisibleTabID = visibleTabID
        let oldActiveTabID = activeTabID
        let oldHasVisibleTabs = hasVisibleTabs

        visibleCategories = categories
        // 分类过滤和指定 tab 过滤是两种互斥的显示模式；切换回分类模式时，
        // 必须清除上一个插件留下的 tab id，否则可能把分类内所有 tab 都过滤掉。
        visibleTabID = nil
        reconcileActiveTab()
        updateVisibleTabState()

        notify(.visibleCategoriesChanged(visibleCategories))
        if visibleTabID != oldVisibleTabID {
            notify(.visibleTabIDChanged(visibleTabID))
        }
        if activeTabID != oldActiveTabID {
            notify(.activeTabChanged(activeTabID))
        }
        if hasVisibleTabs != oldHasVisibleTabs {
            notify(.visibilityChanged(hasVisibleTabs))
        }
    }

    public func setVisibleTabID(_ id: String?) {
        guard visibleTabID != id else { return }
        let oldActiveTabID = activeTabID
        let oldHasVisibleTabs = hasVisibleTabs

        visibleTabID = id
        reconcileActiveTab()
        updateVisibleTabState()

        notify(.visibleTabIDChanged(visibleTabID))
        if activeTabID != oldActiveTabID {
            notify(.activeTabChanged(activeTabID))
        }
        if hasVisibleTabs != oldHasVisibleTabs {
            notify(.visibilityChanged(hasVisibleTabs))
        }
    }

    public func activateWidthProfile(
        ownerID: String,
        recommended: RailViewWidth,
        store: (any RailViewWidthStoring)?
    ) {
        guard !ownerID.isEmpty else { return }
        activeWidthOwnerID = ownerID
        let activeWidthStore = store ?? defaultWidthStore
        self.activeWidthStore = activeWidthStore
        let restoredWidth = activeWidthStore?.loadWidth(ownerID: ownerID) ?? recommended.idealWidth
        let resolvedWidth = recommended.withIdealWidth(recommended.clamped(restoredWidth))
        if railWidth != resolvedWidth {
            railWidth = resolvedWidth
            notify(.widthChanged(railWidth))
        }
    }

    public func deactivateWidthProfile(ownerID: String) {
        guard activeWidthOwnerID == ownerID else { return }
        activeWidthOwnerID = nil
        activeWidthStore = nil
        if railWidth != .standard {
            railWidth = .standard
            notify(.widthChanged(railWidth))
        }
    }

    public func saveCurrentWidth(_ width: CGFloat) {
        guard let activeWidthOwnerID else { return }
        let resolvedWidth = railWidth.clamped(width)
        activeWidthStore?.saveWidth(resolvedWidth, ownerID: activeWidthOwnerID)
        let updatedWidth = railWidth.withIdealWidth(resolvedWidth)
        if railWidth != updatedWidth {
            railWidth = updatedWidth
            notify(.widthChanged(railWidth))
        }
    }

    @discardableResult
    public func addObserver(_ callback: @escaping (RailViewProvidingEvent) -> Void) -> any RailViewProvidingObserverHandle {
        let observer = Observer(owner: self, callback: callback)
        observers.append(WeakObserver(observer))
        return observer
    }

    public func makeRailView() -> AnyView {
        AnyView(RailView(provider: self))
    }

    // MARK: - Observer Infrastructure

    private func remove(_ observer: Observer) {
        observers.removeAll { $0.observer === observer }
    }

    private func notify(_ event: RailViewProvidingEvent) {
        observers.removeAll { $0.observer == nil }
        let activeObservers = observers
        for observer in activeObservers {
            observer.observer?.invoke(event)
        }
    }

    fileprivate var visibleTabs: [RailTabItem] {
        tabs.filter { tab in
            visibleCategories.contains(tab.category)
                && (visibleTabID == nil || tab.id == visibleTabID)
        }
    }

    private func updateVisibleTabState() {
        hasVisibleTabs = !visibleTabs.isEmpty
    }

    private func reconcileActiveTab() {
        guard !visibleTabs.isEmpty else {
            activeTabID = nil
            return
        }
        if let activeTabID, visibleTabs.contains(where: { $0.id == activeTabID }) {
            return
        }
        activeTabID = visibleTabs[0].id
    }

    private final class Observer: RailViewProvidingObserverHandle {
        private weak var owner: DefaultRailViewProviding?
        private let callback: (RailViewProvidingEvent) -> Void
        private var cancelled = false

        init(owner: DefaultRailViewProviding, callback: @escaping (RailViewProvidingEvent) -> Void) {
            self.owner = owner
            self.callback = callback
        }

        func cancel() {
            guard !cancelled else { return }
            cancelled = true
            owner?.remove(self)
        }

        func invoke(_ event: RailViewProvidingEvent) {
            guard !cancelled else { return }
            callback(event)
        }
    }

    private final class WeakObserver {
        weak var observer: Observer?

        init(_ observer: Observer) {
            self.observer = observer
        }
    }
}

/// 渲染「标签栏 + 内容区」的 Rail 视图。
///
/// 视觉与旧版 `FactoryCore` 的 `RailView` + `RailTabBarView` + `RailContentView`
/// 完全一致：
/// - 顶层 `VStack(spacing: 0)`：标签栏 + 内容区（无自带右侧分隔线，
///   分隔线由宿主的 `HSplitView` / `AppDivider` 提供）；
/// - 标签栏复用 `AppToolbarContainer`（height 40、`.panel` 背景、
///   上下 8 / 左右 10 内边距）+ `AppTabBar(showText: false)`（图标式），
///   并带 `borderBottom` + `shadowMd`；仅在 tab 数量大于一个时显示；
/// - 内容区直接渲染激活 tab 视图（`.id` 保持切换动画），无内容时不渲染视图；
/// - 整栏 `minWidth 200`、背景 `theme.surface`。
private struct RailView: View {
    @ObservedObject var provider: DefaultRailViewProviding
    @LumiTheme private var theme

    var body: some View {
        let visibleTabs = provider.visibleTabs

        if visibleTabs.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 0) {
                // 标签栏：仅在 tab 数量大于一个时显示（复刻旧版 showsTabBar）。
                if let firstTab = visibleTabs.first, visibleTabs.count > 1 {
                    AppToolbarContainer(
                        height: 40,
                        backgroundStyle: .panel,
                        padding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
                    ) {
                        AppTabBar(
                            tabs: visibleTabs.map {
                                AppTabBar.Tab(title: $0.title, icon: $0.systemImage, id: $0.id)
                            },
                            selectedTab: Binding(
                                get: { provider.activeTabID ?? firstTab.id },
                                set: { provider.activateTab(id: $0) }
                            ),
                            showText: false
                        )
                    }
                    .borderBottom()
                    .shadowMd()
                }

                // 内容区：激活 tab 视图；未命中时回退首个 tab。
                if let active = visibleTabs.first(where: { $0.id == provider.activeTabID }) {
                    active.makeView()
                        .id(active.id)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let first = visibleTabs.first {
                    first.makeView()
                        .id(first.id)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 200, maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.surface)
        }
    }
}
