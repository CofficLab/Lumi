import Combine
import ProviderRailView
import SwiftUI

/// A reusable stateful root provider with no platform-specific layout.
///
/// Apps may use it directly, or subclass it and override `makeRootView()` to
/// compose the same contributions into a macOS or iOS-specific workbench.
@MainActor
open class DefaultRootViewProviding: RootViewProviding {
    @Published public var views: [RootViewRegion: AnyView] = [:]
    @Published public var hiddenRegions: Set<RootViewRegion> = []
    @Published public var overlays: [RootOverlayItem] = []
    @Published public var trailingPane: RootViewPane?

    @Published public var isRailViewVisible = true
    @Published public var railWidth: RailViewWidth = .standard
    @Published public var isContentViewHidden = false
    @Published public var isContentHeaderViewHidden = false
    @Published public var isContentFooterViewHidden = false
    @Published public var contentFooterHeight: ContentFooterHeight = .standard

    private var observers: [WeakObserver] = []
    private var railVisibilityObserver: (any RailViewProvidingObserverHandle)?
    private var railWidthObserver: (any RailViewProvidingObserverHandle)?
    private var railWidthResizeHandler: (@MainActor (CGFloat) -> Void)?
    private var footerHeightStore: (any ContentFooterHeightStoring)?
    private var footerHeightOwnerID: String?

    public init() {}

    /// Compatibility initializer retained for older factories that passed the
    /// application kernel while constructing the root provider.
    public convenience init<Kernel>(kernel: Kernel) {
        self.init()
    }

    open func view(for region: RootViewRegion) -> AnyView? {
        views[region]
    }

    open func setView(_ view: AnyView?, for region: RootViewRegion) {
        store(view, for: region)
        emitRootViewEvent(.viewChanged(region))
    }

    open func isRegionHidden(_ region: RootViewRegion) -> Bool {
        hiddenRegions.contains(region)
    }

    open func setRegionHidden(_ hidden: Bool, for region: RootViewRegion) {
        if hidden {
            hiddenRegions.insert(region)
        } else {
            hiddenRegions.remove(region)
        }
        emitRootViewEvent(.regionVisibilityChanged(region, isHidden: hidden))
    }

    open func setToolbarView(_ view: AnyView?) {
        store(view, for: .toolbar)
        emitRootViewEvent(.toolbarViewChanged)
    }

    open func setActivityBarView(_ view: AnyView?) {
        store(view, for: .activityBar)
        emitRootViewEvent(.activityBarViewChanged)
    }

    open func setRailView(_ view: AnyView?) {
        // Guard the removal case: re-emitting `.railViewChanged` after the Rail
        // is already absent makes workspace plugins that react to that event by
        // requesting removal again recurse until the stack overflows.
        //
        // `AnyView` is not `Equatable` and SwiftUI exposes no stable way to
        // compare two of them, so an injected view is always treated as new and
        // only the already-empty state is deduplicated. That is safe because
        // `makeRailView()`-style factories return a fresh `AnyView` per call;
        // callers needing a forced replacement can still pass `nil` first.
        guard (views[.rail] == nil) != (view == nil) else { return }
        store(view, for: .rail)
        emitRootViewEvent(.railViewChanged)
    }

    open func setRailViewVisible(_ visible: Bool) {
        guard isRailViewVisible != visible else { return }
        isRailViewVisible = visible
        emitRootViewEvent(.railViewVisibilityChanged(visible))
    }

    open func bindRailViewVisibility(to provider: any RailViewProviding) {
        railVisibilityObserver?.cancel()
        setRailViewVisible(provider.hasVisibleTabs)
        railVisibilityObserver = provider.addObserver { [weak self] event in
            guard case let .visibilityChanged(visible) = event else { return }
            self?.setRailViewVisible(visible)
        }
    }

    open func bindRailViewWidth(
        to provider: any RailViewProviding,
        onResize: @escaping @MainActor (CGFloat) -> Void
    ) {
        railWidthObserver?.cancel()
        railWidthResizeHandler = onResize
        railWidth = provider.railWidth
        emitRootViewEvent(.railWidthChanged(railWidth))
        railWidthObserver = provider.addObserver { [weak self] event in
            guard case let .widthChanged(width) = event else { return }
            self?.railWidth = width
            self?.emitRootViewEvent(.railWidthChanged(width))
        }
    }

    open func saveRailViewWidth(_ width: CGFloat) {
        railWidthResizeHandler?(width)
    }

    open func setContentHeaderView(_ view: AnyView?) {
        store(view, for: .contentHeader)
        emitRootViewEvent(.contentHeaderViewChanged)
    }

    open func setContentHeaderViewHidden(_ hidden: Bool) {
        guard isContentHeaderViewHidden != hidden else { return }
        isContentHeaderViewHidden = hidden
        emitRootViewEvent(.contentHeaderVisibilityChanged(hidden))
    }

    open func setContentView(_ view: AnyView?) {
        store(view, for: .content)
        emitRootViewEvent(.contentViewChanged)
    }

    open func setContentViewHidden(_ hidden: Bool) {
        guard isContentViewHidden != hidden else { return }
        isContentViewHidden = hidden
        emitRootViewEvent(.contentViewVisibilityChanged(hidden))
    }

    open func setContentFooterView(_ view: AnyView?) {
        store(view, for: .contentFooter)
        emitRootViewEvent(.contentFooterViewChanged)
    }

    open func setContentFooterViewHidden(_ hidden: Bool) {
        guard isContentFooterViewHidden != hidden else { return }
        isContentFooterViewHidden = hidden
        emitRootViewEvent(.contentFooterVisibilityChanged(hidden))
    }

    open func activateContentFooterHeightProfile(
        ownerID: String,
        recommended: ContentFooterHeight,
        store: (any ContentFooterHeightStoring)?
    ) {
        guard !ownerID.isEmpty else { return }
        footerHeightOwnerID = ownerID
        footerHeightStore = store
        let restoredHeight = store?.loadHeight(ownerID: ownerID) ?? recommended.idealHeight
        let resolved = recommended.withIdealHeight(recommended.clamped(restoredHeight))
        guard contentFooterHeight != resolved else { return }
        contentFooterHeight = resolved
        emitRootViewEvent(.contentFooterHeightChanged(resolved))
    }

    open func deactivateContentFooterHeightProfile(ownerID: String) {
        guard footerHeightOwnerID == ownerID else { return }
        footerHeightOwnerID = nil
        footerHeightStore = nil
        guard contentFooterHeight != .standard else { return }
        contentFooterHeight = .standard
        emitRootViewEvent(.contentFooterHeightChanged(.standard))
    }

    open func saveCurrentContentFooterHeight(_ height: CGFloat) {
        guard let footerHeightOwnerID else { return }
        let resolved = contentFooterHeight.clamped(height)
        footerHeightStore?.saveHeight(resolved, ownerID: footerHeightOwnerID)
        let updated = contentFooterHeight.withIdealHeight(resolved)
        guard contentFooterHeight != updated else { return }
        contentFooterHeight = updated
        emitRootViewEvent(.contentFooterHeightChanged(updated))
    }

    open func addOverlays(_ newOverlays: [RootOverlayItem]) {
        var merged = overlays
        for overlay in newOverlays {
            if let index = merged.firstIndex(where: { $0.id == overlay.id }) {
                merged[index] = overlay
            } else {
                merged.append(overlay)
            }
        }
        overlays = merged.sorted {
            if $0.order != $1.order { return $0.order < $1.order }
            return $0.id < $1.id
        }
        emitRootViewEvent(.overlaysChanged)
    }

    open func removeOverlays(ids: Set<String>) {
        overlays.removeAll { ids.contains($0.id) }
        emitRootViewEvent(.overlaysChanged)
    }

    open func setTrailingPane(_ pane: RootViewPane?) {
        trailingPane = pane
        emitRootViewEvent(.trailingPaneChanged)
    }

    @discardableResult
    open func addRootViewObserver(
        _ callback: @escaping (RootViewEvent) -> Void
    ) -> any RootViewObserverHandle {
        let observer = Observer(owner: self, callback: callback)
        observers.append(WeakObserver(observer))
        return observer
    }

    open func makeRootView() -> AnyView {
        var root = contentView ?? AnyView(EmptyView())
        for overlay in overlays {
            root = overlay.wrap(root)
        }
        return root
    }

    /// Publishes an event for an app-specific subclass.
    ///
    /// Prunes released observers first so a dropped handle stops receiving
    /// events immediately, matching `RailViewProviding` / `CommandProviding`.
    /// Without the prune, a callback that captured an object would keep that
    /// object alive for the provider's whole lifetime.
    open func emitRootViewEvent(_ event: RootViewEvent) {
        observers.removeAll { $0.observer == nil }
        for entry in observers {
            entry.observer?.invoke(event)
        }
    }

    public var toolbarView: AnyView? {
        get { view(for: .toolbar) }
        set { setToolbarView(newValue) }
    }

    public var activityBarView: AnyView? {
        get { view(for: .activityBar) }
        set { setActivityBarView(newValue) }
    }

    public var railView: AnyView? {
        get { view(for: .rail) }
        set { setRailView(newValue) }
    }

    public var contentHeaderView: AnyView? {
        get { view(for: .contentHeader) }
        set { setContentHeaderView(newValue) }
    }

    public var contentView: AnyView? {
        get { view(for: .content) }
        set { setContentView(newValue) }
    }

    public var contentFooterView: AnyView? {
        get { view(for: .contentFooter) }
        set { setContentFooterView(newValue) }
    }

    public var statusBarView: AnyView? {
        get { view(for: .statusBar) }
        set { setView(newValue, for: .statusBar) }
    }

    private func store(_ view: AnyView?, for region: RootViewRegion) {
        if let view {
            views[region] = view
        } else {
            views.removeValue(forKey: region)
        }
    }

    private func remove(_ observer: Observer) {
        observers.removeAll { $0.observer === observer }
    }

    /// Observer token returned by `addRootViewObserver`.
    ///
    /// The provider only keeps a weak reference, so callers must hold the
    /// handle for as long as they want events. Dropping it stops delivery.
    private final class Observer: RootViewObserverHandle {
        private weak var owner: DefaultRootViewProviding?
        private let callback: (RootViewEvent) -> Void
        private var isCancelled = false

        init(owner: DefaultRootViewProviding, callback: @escaping (RootViewEvent) -> Void) {
            self.owner = owner
            self.callback = callback
        }

        func cancel() {
            guard !isCancelled else { return }
            isCancelled = true
            owner?.remove(self)
            owner = nil
        }

        func invoke(_ event: RootViewEvent) {
            guard !isCancelled else { return }
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
