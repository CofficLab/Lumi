import Combine
import ProviderRailView
import SwiftUI

/// The platform-neutral regions a root host may choose to render.
@MainActor
public enum RootViewRegion: String, CaseIterable, Sendable {
    case toolbar
    case activityBar
    case sidebar
    case rail
    case contentHeader
    case content
    case contentFooter
    case statusBar
}

/// Events emitted when a root-view contribution changes.
@MainActor
public enum RootViewEvent {
    case viewChanged(RootViewRegion)
    case regionVisibilityChanged(RootViewRegion, isHidden: Bool)
    case overlaysChanged
    case trailingPaneChanged

    // Compatibility events for richer desktop hosts.
    case toolbarViewChanged
    case activityBarViewChanged
    case railViewChanged
    case railViewVisibilityChanged(Bool)
    case railWidthChanged(RailViewWidth)
    case contentHeaderViewChanged
    case contentHeaderVisibilityChanged(Bool)
    case contentViewChanged
    case contentViewVisibilityChanged(Bool)
    case contentFooterViewChanged
    case contentFooterVisibilityChanged(Bool)
    case contentFooterHeightChanged(ContentFooterHeight)
}

@MainActor
public protocol RootViewObserverHandle: AnyObject {
    func cancel()
}

/// A contribution that wraps the assembled root content.
@MainActor
public struct RootOverlayItem: Identifiable {
    public let id: String
    public let order: Int
    public let wrap: @MainActor (AnyView) -> AnyView

    public init<Content: View>(
        id: String,
        order: Int = 0,
        @ViewBuilder wrap: @escaping @MainActor (AnyView) -> Content
    ) {
        self.id = id
        self.order = order
        self.wrap = { AnyView(wrap($0)) }
    }
}

/// A platform-neutral trailing pane contribution.
///
/// Width values are recommendations. A host may render the pane as a desktop
/// column, an iOS sheet, or a navigation destination.
@MainActor
open class RootViewPane: ObservableObject, Identifiable {
    public let id: String
    public let content: AnyView

    @Published public private(set) var minWidth: CGFloat
    @Published public private(set) var idealWidth: CGFloat
    @Published public private(set) var maxWidth: CGFloat
    private var visibilityStorage: Bool

    open var isVisible: Bool {
        get { visibilityStorage }
        set {
            guard visibilityStorage != newValue else { return }
            visibilityStorage = newValue
            objectWillChange.send()
            visibilityDidChange(newValue)
        }
    }

    public init(
        id: String,
        minWidth: CGFloat = 280,
        idealWidth: CGFloat = 320,
        maxWidth: CGFloat = .infinity,
        isVisible: Bool = true,
        content: AnyView
    ) {
        self.id = id
        self.content = content
        self.minWidth = minWidth
        self.idealWidth = idealWidth
        self.maxWidth = maxWidth
        self.visibilityStorage = isVisible
    }

    public convenience init<Content: View>(
        id: String,
        minWidth: CGFloat = 280,
        idealWidth: CGFloat = 320,
        maxWidth: CGFloat = .infinity,
        isVisible: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            id: id,
            minWidth: minWidth,
            idealWidth: idealWidth,
            maxWidth: maxWidth,
            isVisible: isVisible,
            content: AnyView(content())
        )
    }

    /// Allows an app-specific pane subclass to update its recommended width.
    open func updateDimensions(
        minWidth: CGFloat,
        idealWidth: CGFloat,
        maxWidth: CGFloat
    ) {
        self.minWidth = minWidth
        self.idealWidth = idealWidth
        self.maxWidth = maxWidth
    }

    /// Called by a host after a user resizes the pane. The default is a no-op.
    open func saveWidth(_ width: CGFloat) {}

    /// Hook for app-specific panes that expose typed visibility events.
    open func visibilityDidChange(_ isVisible: Bool) {}
}

/// The common root-view capability contract shared by macOS and iOS hosts.
///
/// The protocol describes contributions and state, not a single layout. A
/// small app can use `DefaultRootViewProviding`; a workbench app can subclass
/// it and override `makeRootView()` with its own macOS or iOS composition.
@MainActor
public protocol RootViewProviding: AnyObject, ObservableObject {
    func view(for region: RootViewRegion) -> AnyView?
    func setView(_ view: AnyView?, for region: RootViewRegion)

    func isRegionHidden(_ region: RootViewRegion) -> Bool
    func setRegionHidden(_ hidden: Bool, for region: RootViewRegion)

    var overlays: [RootOverlayItem] { get }
    func addOverlays(_ overlays: [RootOverlayItem])
    func removeOverlays(ids: Set<String>)

    /// 注册根视图变更观察者。
    ///
    /// 调用方**必须持有**返回的句柄：provider 只保留弱引用，
    /// 句柄被释放后回调停止投递（或在下次发事件时被清理）。
    /// 需要提前停止时显式调用 `cancel()`，重复调用无副作用。
    func addRootViewObserver(
        _ callback: @escaping (RootViewEvent) -> Void
    ) -> any RootViewObserverHandle

    func setToolbarView(_ view: AnyView?)
    func setActivityBarView(_ view: AnyView?)
    func setRailView(_ view: AnyView?)

    var isRailViewVisible: Bool { get }
    func setRailViewVisible(_ visible: Bool)
    func bindRailViewVisibility(to provider: any RailViewProviding)

    var railWidth: RailViewWidth { get }
    func bindRailViewWidth(
        to provider: any RailViewProviding,
        onResize: @escaping @MainActor (CGFloat) -> Void
    )

    func setContentHeaderView(_ view: AnyView?)
    var isContentHeaderViewHidden: Bool { get }
    func setContentHeaderViewHidden(_ hidden: Bool)

    func setContentView(_ view: AnyView?)
    var isContentViewHidden: Bool { get }
    func setContentViewHidden(_ hidden: Bool)

    func setContentFooterView(_ view: AnyView?)
    var isContentFooterViewHidden: Bool { get }
    func setContentFooterViewHidden(_ hidden: Bool)

    var contentFooterHeight: ContentFooterHeight { get }
    func activateContentFooterHeightProfile(
        ownerID: String,
        recommended: ContentFooterHeight,
        store: (any ContentFooterHeightStoring)?
    )
    func deactivateContentFooterHeightProfile(ownerID: String)
    func saveCurrentContentFooterHeight(_ height: CGFloat)

    var trailingPane: RootViewPane? { get }
    func setTrailingPane(_ pane: RootViewPane?)

    func makeRootView() -> AnyView
}

/// Compatibility name used by older Lumi/Cisum factories.
public typealias DefaultRootViewProvider = DefaultRootViewProviding

public extension RootViewProviding {
    func view(for region: RootViewRegion) -> AnyView? { nil }
    func setView(_ view: AnyView?, for region: RootViewRegion) {}

    func isRegionHidden(_ region: RootViewRegion) -> Bool { false }
    func setRegionHidden(_ hidden: Bool, for region: RootViewRegion) {}

    var overlays: [RootOverlayItem] { [] }
    func addOverlays(_ overlays: [RootOverlayItem]) {}
    func removeOverlays(ids: Set<String>) {}

    /// Compatibility overload retained for older Lumi/Cisum hosts.
    func removeOverlays(ids: [String]) {
        removeOverlays(ids: Set(ids))
    }

    func addRootViewObserver(
        _ callback: @escaping (RootViewEvent) -> Void
    ) -> any RootViewObserverHandle {
        NoopRootViewObserverHandle()
    }

    func setToolbarView(_ view: AnyView?) { setView(view, for: .toolbar) }
    func setActivityBarView(_ view: AnyView?) { setView(view, for: .activityBar) }
    func setRailView(_ view: AnyView?) { setView(view, for: .rail) }

    /// Compatibility slots used by the older desktop workbench contract.
    func setControlView(_ view: AnyView?) { setContentHeaderView(view) }
    func setStatusView(_ view: AnyView?) { setView(view, for: .statusBar) }
    func setToolbarContent(_ view: AnyView?) { setToolbarView(view) }

    var isRailViewVisible: Bool { true }
    func setRailViewVisible(_ visible: Bool) {}
    func bindRailViewVisibility(to provider: any RailViewProviding) {}

    var railWidth: RailViewWidth { .standard }
    func bindRailViewWidth(
        to provider: any RailViewProviding,
        onResize: @escaping @MainActor (CGFloat) -> Void
    ) {}

    func setContentHeaderView(_ view: AnyView?) { setView(view, for: .contentHeader) }
    var isContentHeaderViewHidden: Bool { false }
    func setContentHeaderViewHidden(_ hidden: Bool) { setRegionHidden(hidden, for: .contentHeader) }

    func setContentView(_ view: AnyView?) { setView(view, for: .content) }
    var isContentViewHidden: Bool { false }
    func setContentViewHidden(_ hidden: Bool) { setRegionHidden(hidden, for: .content) }

    /// Compatibility visibility helpers retained for older desktop hosts.
    var isContentViewVisible: Bool { !isContentViewHidden }
    func setContentViewVisible(_ visible: Bool) { setContentViewHidden(!visible) }
    func showContentView() { setContentViewVisible(true) }
    func hideContentView() { setContentViewVisible(false) }
    func toggleContentView() { setContentViewVisible(!isContentViewVisible) }

    func setContentFooterView(_ view: AnyView?) { setView(view, for: .contentFooter) }
    var isContentFooterViewHidden: Bool { false }
    func setContentFooterViewHidden(_ hidden: Bool) { setRegionHidden(hidden, for: .contentFooter) }

    var contentFooterHeight: ContentFooterHeight { .standard }
    func activateContentFooterHeightProfile(
        ownerID: String,
        recommended: ContentFooterHeight,
        store: (any ContentFooterHeightStoring)?
    ) {}
    func deactivateContentFooterHeightProfile(ownerID: String) {}
    func saveCurrentContentFooterHeight(_ height: CGFloat) {}

    var trailingPane: RootViewPane? { nil }
    func setTrailingPane(_ pane: RootViewPane?) {}

    var toolbarView: AnyView? { view(for: .toolbar) }
    var activityBarView: AnyView? { view(for: .activityBar) }
    var controlView: AnyView? {
        get { view(for: .contentHeader) }
        set { setControlView(newValue) }
    }
    var sidebarView: AnyView? { view(for: .sidebar) }
    var railView: AnyView? { view(for: .rail) }
    var contentHeaderView: AnyView? { view(for: .contentHeader) }
    var contentView: AnyView? { view(for: .content) }
    var contentFooterView: AnyView? { view(for: .contentFooter) }
    var statusBarView: AnyView? { view(for: .statusBar) }

    func setSidebarView(_ view: AnyView?) { setView(view, for: .sidebar) }
    func setStatusBarView(_ view: AnyView?) { setView(view, for: .statusBar) }

    func setToolbarViewHidden(_ hidden: Bool) { setRegionHidden(hidden, for: .toolbar) }
    func setActivityBarViewHidden(_ hidden: Bool) { setRegionHidden(hidden, for: .activityBar) }
    func setSidebarViewHidden(_ hidden: Bool) { setRegionHidden(hidden, for: .sidebar) }
    func setRailViewHidden(_ hidden: Bool) { setRegionHidden(hidden, for: .rail) }
    func setStatusBarViewHidden(_ hidden: Bool) { setRegionHidden(hidden, for: .statusBar) }

    var isToolbarViewHidden: Bool { isRegionHidden(.toolbar) }
    var isActivityBarViewHidden: Bool { isRegionHidden(.activityBar) }
    var isSidebarViewHidden: Bool { isRegionHidden(.sidebar) }
    var isRailViewHidden: Bool { isRegionHidden(.rail) }
    var isContentHeaderViewHiddenByRegion: Bool { isRegionHidden(.contentHeader) }
    var isContentViewHiddenByRegion: Bool { isRegionHidden(.content) }
    var isContentFooterViewHiddenByRegion: Bool { isRegionHidden(.contentFooter) }
    var isStatusBarViewHidden: Bool { isRegionHidden(.statusBar) }

    func makeRootView() -> AnyView {
        var root = contentView ?? AnyView(EmptyView())
        for overlay in overlays.sorted(by: { $0.order < $1.order }) {
            root = overlay.wrap(root)
        }
        return root
    }
}

@MainActor
private final class NoopRootViewObserverHandle: RootViewObserverHandle {
    func cancel() {}
}
