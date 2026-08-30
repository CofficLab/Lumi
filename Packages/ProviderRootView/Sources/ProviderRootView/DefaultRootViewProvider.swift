import Combine
import LumiUI
import KitSuperLog
import os
import ProviderRailView
import SwiftUI

/// `RootViewProviding` 的默认实现：持有注入的工具栏、ActivityBar、Rail、内容 Header、
/// 主内容视图与 Footer，组合成「顶部工具栏 + 内容区（左侧 ActivityBar，右侧 Rail）」
/// 的根布局（与旧版 `AppLayoutView` 完全一致）。
///
/// 与旧版 `AppLayoutView` 对齐的行为：
/// - 主内容未注入、且无活跃内容时显示 `WelcomeView` 风格的欢迎占位；
/// - ActivityBar 在存在至少两个入口时显示；
/// - Rail 由宿主统一注入后常驻显示，不受当前插件容器影响；
/// - 根视图应用主题背景、`appThemedAppearance`、`ThemeWindowAppearanceBridge`
///   与 `AppThemeVM` 环境对象（复刻旧版主题链）。
@MainActor
public final class DefaultRootViewProvider: RootViewProviding, ObservableObject, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.provider-root-view", category: "ProviderRootView")
    nonisolated public static let emoji = "🏠"
    nonisolated static let verbose = false

    @Published var toolbarView: AnyView?
    @Published var activityBarView: AnyView?
    @Published var railView: AnyView?
    @Published var contentHeaderView: AnyView?
    @Published var contentView: AnyView?
    @Published var contentFooterView: AnyView?
    @Published var trailingPane: RootTrailingPane?
    @Published public private(set) var isRailViewVisible = true
    @Published public private(set) var railWidth: RailViewWidth = .standard
    @Published public private(set) var overlays: [RootOverlayItem] = []
    @Published public private(set) var isContentViewHidden: Bool = false
    @Published public private(set) var isContentHeaderViewHidden: Bool = false
    private var railVisibilitySubscription: AnyCancellable?
    private var railWidthSubscription: AnyCancellable?
    private var railWidthResizeHandler: (@MainActor (CGFloat) -> Void)?
    private var lastRailViewVisibility = true
    public init() {
        if Self.verbose {
            Self.logger.info("\(self.t)DefaultRootViewProviding initialized")
        }
    }

    public func setToolbarView(_ view: AnyView?) {
        guard !isSameView(toolbarView, view) else { return }
        toolbarView = view
        if Self.verbose {
            Self.logger.debug("\(self.t)set toolbar view: \(view == nil ? "nil" : "injected")")
        }
    }

    public func addOverlays(_ newOverlays: [RootOverlayItem]) {
        for overlay in newOverlays where !overlays.contains(where: { $0.id == overlay.id }) { overlays.append(overlay) }
        overlays.sort { $0.order < $1.order }
    }

    public func removeOverlays(ids: Set<String>) { overlays.removeAll { ids.contains($0.id) } }

    public func setActivityBarView(_ view: AnyView?) {
        guard !isSameView(activityBarView, view) else { return }
        activityBarView = view
        if Self.verbose {
            Self.logger.debug("\(self.t)set activity bar view: \(view == nil ? "nil" : "injected")")
        }
    }

    public func setRailView(_ view: AnyView?) {
        guard !isSameView(railView, view) else { return }
        if view == nil {
            // `setRailView(nil)` can be a temporary host-level replacement. Keep
            // the provider's latest visibility so restoring the Rail view does
            // not show an empty area while its tabs are still hidden.
            if isRailViewVisible {
                isRailViewVisible = false
            }
        } else if railView == nil {
            setRailViewVisible(lastRailViewVisibility)
        }
        railView = view
        if Self.verbose {
            Self.logger.debug("\(self.t)set rail view: \(view == nil ? "nil" : "injected")")
        }
    }

    public func setRailViewVisible(_ visible: Bool) {
        guard isRailViewVisible != visible else { return }
        isRailViewVisible = visible
        lastRailViewVisibility = visible
    }

    public func bindRailViewVisibility(to publisher: AnyPublisher<Bool, Never>) {
        railVisibilitySubscription = publisher.sink { [weak self] visible in
            Task { @MainActor [weak self] in
                self?.setRailViewVisible(visible)
            }
        }
    }

    public func bindRailViewWidth(
        to publisher: AnyPublisher<RailViewWidth, Never>,
        onResize: @escaping @MainActor (CGFloat) -> Void
    ) {
        railWidthResizeHandler = onResize
        railWidthSubscription = publisher.sink { [weak self] width in
            Task { @MainActor [weak self] in
                self?.railWidth = width
            }
        }
    }

    func saveRailViewWidth(_ width: CGFloat) {
        railWidthResizeHandler?(width)
    }

    public func setContentHeaderView(_ view: AnyView?) {
        guard !isSameView(contentHeaderView, view) else { return }
        contentHeaderView = view
        if Self.verbose {
            Self.logger.debug("\(self.t)set content header view: \(view == nil ? "nil" : "injected")")
        }
    }

    public func setContentView(_ view: AnyView?) {
        guard !isSameView(contentView, view) else { return }
        contentView = view
        if Self.verbose {
            Self.logger.debug("\(self.t)set content view: \(view == nil ? "nil" : "injected")")
        }
    }

    public func setContentFooterView(_ view: AnyView?) {
        guard !isSameView(contentFooterView, view) else { return }
        contentFooterView = view
        if Self.verbose {
            Self.logger.debug("\(self.t)set content footer view: \(view == nil ? "nil" : "injected")")
        }
    }

    public func setContentViewHidden(_ hidden: Bool) {
        guard isContentViewHidden != hidden else { return }
        isContentViewHidden = hidden
        if Self.verbose {
            Self.logger.debug("\(self.t)set content view hidden: \(hidden)")
        }
    }

    public func setContentHeaderViewHidden(_ hidden: Bool) {
        guard isContentHeaderViewHidden != hidden else { return }
        isContentHeaderViewHidden = hidden
        if Self.verbose {
            Self.logger.debug("\(self.t)set content header hidden: \(hidden)")
        }
    }

    public func setTrailingPane(_ pane: RootTrailingPane?) {
        guard pane !== trailingPane else { return }
        trailingPane = pane
        if Self.verbose {
            Self.logger.debug("\(self.t)set trailing pane: \(pane.map { $0.id } ?? "nil")")
        }
    }

    // MARK: - 注入守卫（值相同则跳过赋值）

    /// 判断两次注入的视图是否「相同」：仅比较有值/无值状态。
    ///
    /// `AnyView` 不遵循 `Equatable`，SwiftUI 也未公开 unerase API（反射内部
    /// storage 在 Release 下不可靠）。因此这里采用保守且可预测的判定：
    /// - 状态相同（均为 nil 或均为非 nil）→ 视为相同，跳过赋值；
    /// - 状态不同（nil ↔ 非 nil）→ 视为变化，正常更新。
    ///
    /// 目的：装配流程可能重复调用注入方法（如宿主重建视图树时）
    /// 导致 App body 重求值后再次装配），重复赋值 `@Published` 会在视图更新期间
    /// 发布变更，触发 SwiftUI 的 "Publishing changes from within view updates
    /// is not allowed" 并可能形成循环。状态相同即跳过，避免无意义发布。
    ///
    /// 注意：这是保守近似 —— 已注入非 nil 视图后，再次注入任意新视图（含不同
    /// 类型）都会被跳过。Lumi 架构下视图内容更新由视图内部状态驱动（Provider
    /// 的 `@Published`/`objectWillChange`），无需重新注入新 `AnyView`；若确有
    /// Provider 需要强制替换，可先传 nil 再传新值。
    private func isSameView(_ lhs: AnyView?, _ rhs: AnyView?) -> Bool {
        (lhs == nil) == (rhs == nil)
    }

    public func makeRootView() -> AnyView {
        if Self.verbose {
            Self.logger.debug("\(self.t)make root view: toolbar=\(self.toolbarView == nil ? "nil" : "set"), activityBar=\(self.activityBarView == nil ? "nil" : "set"), rail=\(self.railView == nil ? "nil" : "set"), content=\(self.contentView == nil ? "nil" : "set"), footer=\(self.contentFooterView == nil ? "nil" : "set")")
        }
        var root = AnyView(DefaultRootHostView(provider: self))
        for overlay in overlays { root = overlay.wrap(root) }
        return root
    }

    // MARK: - 显示条件

    /// 是否存在可渲染的活跃内容。
    ///
    /// 内容插件的容器状态不是根视图渲染的必要条件。ChatPanel 由
    /// ActivityBar + ChatSection 驱动，只要 trailing pane 可见就应正常显示。
    var hasActiveContent: Bool {
        return contentHeaderView != nil || contentView != nil || contentFooterView != nil || trailingPane?.isVisible == true
    }
}
