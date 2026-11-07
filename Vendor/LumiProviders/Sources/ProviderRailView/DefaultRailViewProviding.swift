import Combine
import LumiUI
import SwiftUI

/// `RailViewProviding` 的默认实现：持有注入的 `RailTabItem`，
/// 渲染为「顶部标签栏 + 内容区」的侧边栏（与旧版 `FactoryCore.RailView` 视觉一致）。
///
/// 点击 tab 切换选中项并展示对应内容。
@MainActor
public final class DefaultRailViewProviding: RailViewProviding {
    public private(set) var tabs: [RailTabItem] = []
    public private(set) var visibleCategories: Set<RailViewCategory>
    public private(set) var visibleTabID: String?
    public private(set) var activeTabID: String?
    public private(set) var hasVisibleTabs = false
    public private(set) var sections: [RailSectionItem] = []
    public private(set) var bottomItems: [RailBottomItem] = []
    public private(set) var railWidth: RailViewWidth

    public var hasVisibleSections: Bool { !sections.isEmpty }
    public var hasVisibleBottomItems: Bool { !bottomItems.isEmpty }
    public var railVisibilityPublisher: AnyPublisher<Bool, Never> {
        railVisibilitySubject.eraseToAnyPublisher()
    }
    public var railWidthPublisher: AnyPublisher<RailViewWidth, Never> {
        railWidthSubject.eraseToAnyPublisher()
    }

    private let defaultWidthStore: (any RailViewWidthStoring)?
    private var activeWidthStore: (any RailViewWidthStoring)?
    private var activeWidthOwnerID: String?
    private var pendingActiveTabID: String?
    private let railVisibilitySubject = CurrentValueSubject<Bool, Never>(false)
    private let railWidthSubject = CurrentValueSubject<RailViewWidth, Never>(.standard)

    private var observers: [WeakObserver] = []

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
        self.pendingActiveTabID = nil
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
        if activeTabID != oldActiveTabID, pendingActiveTabID == nil {
            notify(.activeTabChanged(activeTabID))
        }
        if hasVisibleTabs != oldHasVisibleTabs {
            notify(.visibilityChanged(hasVisibleTabs))
        }
        publishRailVisibility()
    }

    public func registerSections(_ newSections: [RailSectionItem]) {
        sections = newSections.sorted { $0.order < $1.order }
        publishRailVisibility()
    }

    public func addSections(_ newSections: [RailSectionItem]) {
        var merged = sections
        for section in newSections where !merged.contains(where: { $0.id == section.id }) {
            merged.append(section)
        }
        registerSections(merged)
    }

    public func removeSections(ids: Set<String>) {
        registerSections(sections.filter { !ids.contains($0.id) })
    }

    public func registerBottomItems(_ newItems: [RailBottomItem]) {
        let oldIDs = bottomItems.map(\.id)
        let newIDs = newItems.map(\.id)
        bottomItems = newItems.sorted { $0.order < $1.order }
        guard oldIDs != newIDs else { return }
        notify(.bottomItemsChanged(bottomItems))
    }

    public func addBottomItems(_ newItems: [RailBottomItem]) {
        var merged = bottomItems
        for item in newItems where !merged.contains(where: { $0.id == item.id }) {
            merged.append(item)
        }
        registerBottomItems(merged)
    }

    public func removeBottomItems(ids: Set<String>) {
        registerBottomItems(bottomItems.filter { !ids.contains($0.id) })
    }

    public func activateTab(id: String?) {
        let oldActiveTabID = activeTabID
        guard let id else {
            let hadPendingActiveTab = pendingActiveTabID != nil
            pendingActiveTabID = nil
            activeTabID = nil
            if activeTabID != oldActiveTabID || hadPendingActiveTab {
                notify(.activeTabChanged(activeTabID))
            }
            return
        }
        guard visibleTabs.contains(where: { $0.id == id }) else { return }
        let hadPendingActiveTab = pendingActiveTabID != nil
        pendingActiveTabID = nil
        activeTabID = id
        if activeTabID != oldActiveTabID || hadPendingActiveTab {
            notify(.activeTabChanged(activeTabID))
        }
    }

    public func activateTabWhenAvailable(id: String?) {
        guard let id else {
            pendingActiveTabID = nil
            activateTab(id: nil)
            return
        }

        guard visibleTabs.contains(where: { $0.id == id }) else {
            pendingActiveTabID = id
            return
        }

        pendingActiveTabID = nil
        activateTab(id: id)
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
        if activeTabID != oldActiveTabID, pendingActiveTabID == nil {
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
        if activeTabID != oldActiveTabID, pendingActiveTabID == nil {
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
            railWidthSubject.send(railWidth)
            notify(.widthChanged(railWidth))
        }
    }

    public func deactivateWidthProfile(ownerID: String) {
        guard activeWidthOwnerID == ownerID else { return }
        activeWidthOwnerID = nil
        activeWidthStore = nil
        if railWidth != .standard {
            railWidth = .standard
            railWidthSubject.send(railWidth)
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
            railWidthSubject.send(railWidth)
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

    fileprivate func notify(_ event: RailViewProvidingEvent) {
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

    private func publishRailVisibility() {
        railVisibilitySubject.send(hasVisibleTabs || hasVisibleSections)
    }

    private func reconcileActiveTab() {
        guard !visibleTabs.isEmpty else {
            activeTabID = nil
            return
        }
        if let pendingActiveTabID,
           visibleTabs.contains(where: { $0.id == pendingActiveTabID }) {
            activeTabID = pendingActiveTabID
            self.pendingActiveTabID = nil
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
    let provider: DefaultRailViewProviding
    @LumiTheme private var theme
    @State private var observationRevision = 0
    @State private var observerHandle: (any RailViewProvidingObserverHandle)?

    var body: some View {
        // Read the local token so provider events invalidate this view without
        // changing the identity of the entire Rail content tree.
        let _ = observationRevision
        content
            .onAppear {
                guard observerHandle == nil else { return }
                observerHandle = provider.addObserver { event in
                    // Width is a layout-only update from the host split view. Do not
                    // rebuild the Rail content tree for it: doing so destroys and
                    // recreates consumers such as the conversation list while the
                    // native NSSplitView is finishing its resize pass.
                    guard case .widthChanged = event else {
                        observationRevision += 1
                        return
                    }
                }
                provider.notify(.didAppear)
            }
            .onDisappear {
                observerHandle?.cancel()
                observerHandle = nil
            }
    }

    @ViewBuilder
    private var content: some View {
        let visibleTabs = provider.visibleTabs

        if !provider.sections.isEmpty {
            VStack(spacing: 0) {
                ForEach(provider.sections) { section in
                    section.makeView()
                        .frame(maxWidth: .infinity)
                }

                RailBottomView(items: provider.bottomItems)
            }
            .frame(minWidth: 200, maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.surface)
        } else if visibleTabs.isEmpty {
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
                // 内容区吃掉除底部固定项以外的全部高度，底部固定项因此始终贴在底边。
                if let active = visibleTabs.first(where: { $0.id == provider.activeTabID }) {
                    active.makeView()
                        .id(active.id)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let first = visibleTabs.first {
                    first.makeView()
                        .id(first.id)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                RailBottomView(items: provider.bottomItems)
            }
            .frame(minWidth: 200, maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.surface)
        }
    }
}

/// Rail 底部固定区：承载插件注入的跨标签常驻状态信息。
///
/// 固定在 Rail 内容区底部，宽度随 Rail 宽度伸缩；Rail 不可见时随 Rail 一并消失。
/// 高度默认与 ChatSection 的 action bar 对齐（`AppPanelChromeMetrics.actionBarHeight`），
/// 插件可在 `RailBottomItem.height` 中声明其它高度。
@MainActor
private struct RailBottomView: View {
    let items: [RailBottomItem]

    var body: some View {
        if !items.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    item.makeView()
                        .frame(maxWidth: .infinity)
                        .frame(height: item.height ?? AppPanelChromeMetrics.actionBarHeight)
                        .clipped()

                    if index < items.count - 1 {
                        AppDivider()
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
        }
    }
}
