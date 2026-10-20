import Combine
import LumiUI
import LumiLoggingKit
import os
import ProviderRootView
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
public final class LumiRootViewProvider: DefaultRootViewProviding, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.provider-root-view", category: "ProviderRootView")
    nonisolated public static let emoji = "🏠"
    nonisolated static let verbose = false

    private var railVisibilityObserver: (any RailViewProvidingObserverHandle)?
    private var railWidthObserver: (any RailViewProvidingObserverHandle)?
    private var railWidthResizeHandler: (@MainActor (CGFloat) -> Void)?
    private var activeContentFooterHeightStore: (any ContentFooterHeightStoring)?
    private var activeContentFooterHeightOwnerID: String?
    private var lastRailViewVisibility = true

    /// 已绑定的 Rail Provider（弱引用，仅用于重新计算 `hasRailContent`）。
    private weak var boundRailProvider: (any RailViewProviding)?

    /// Rail 当前是否有**可渲染内容**（可见标签或区块）。
    ///
    /// ## 为什么需要它：空的 split 面板会被折叠，且再也回不来
    ///
    /// `isRailViewVisible` 只表达「宿主是否允许显示 Rail」，不表达「Rail 里有没有东西」。
    /// 全新安装时两者会在启动早期分叉：会话列表的 `chats` 标签要等数据首次加载
    /// （异步计数 + 去抖）才注册，而 `ChatPanel` 在 boot 期就无条件把 Rail 置为可见。
    /// 于是首帧渲染出一个**没有任何标签的空 Rail 面板**，`HSplitView` 把这一侧折叠成
    /// 0 宽；随后标签注册成功，`NSSplitView` 也不会自动把分隔条推回去 ——
    /// 表现为「会话已存在、日志显示 `hasVisibleTabs=true`，但界面上永远看不到会话列表」。
    ///
    /// `WorkbenchSplitView` 用本属性做 split 视图的 identity（`.id`）：内容从无到有
    /// 时整块重建，让 Rail 以 `idealWidth` 重新布局一次。**不能**把它塞进
    /// `showsRail` 的判定里把面板整个摘掉 —— 那会改变主内容的视图层级，导致
    /// SwiftUI 把祖先的 `root.main` 标识符覆盖到后代控件上，发送按钮等控件
    /// 会连同其可访问性标识符一起从 AX 树里消失。
    ///
    /// - Note: 未调用 `bindRailViewVisibility(to:)` 的宿主保持旧行为（恒为 `true`），
    ///   因为拿不到 `RailViewProviding` 时无法判断内容，也不该改变它们的渲染结果。
    @Published public private(set) var hasRailContent = true
    public override init() {
        super.init()
        if Self.verbose {
            Self.logger.info("\(self.t)DefaultRootViewProviding initialized")
        }
    }


    public override func setToolbarView(_ view: AnyView?) {
        guard !isSameView(toolbarView, view) else { return }
        super.setToolbarView(view)
        if Self.verbose {
            Self.logger.debug("\(self.t)set toolbar view: \(view == nil ? "nil" : "injected")")
        }
    }

    public override func addOverlays(_ newOverlays: [RootOverlayItem]) {
        let oldCount = overlays.count
        for overlay in newOverlays where !overlays.contains(where: { $0.id == overlay.id }) { overlays.append(overlay) }
        overlays.sort { $0.order < $1.order }
        if overlays.count != oldCount {
            emitRootViewEvent(.overlaysChanged)
        }
    }

    public override func removeOverlays(ids: Set<String>) {
        let oldCount = overlays.count
        overlays.removeAll { ids.contains($0.id) }
        if overlays.count != oldCount {
            emitRootViewEvent(.overlaysChanged)
        }
    }

    public override func setActivityBarView(_ view: AnyView?) {
        guard !isSameView(activityBarView, view) else { return }
        super.setActivityBarView(view)
        if Self.verbose {
            Self.logger.debug("\(self.t)set activity bar view: \(view == nil ? "nil" : "injected")")
        }
    }

    public override func setRailView(_ view: AnyView?) {
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
        super.setRailView(view)
        if Self.verbose {
            Self.logger.debug("\(self.t)set rail view: \(view == nil ? "nil" : "injected")")
        }
    }

    public override func setRailViewVisible(_ visible: Bool) {
        guard isRailViewVisible != visible else { return }
        isRailViewVisible = visible
        lastRailViewVisibility = visible
        emitRootViewEvent(.railViewVisibilityChanged(visible))
    }

    public override func bindRailViewVisibility(to provider: any RailViewProviding) {
        railVisibilityObserver?.cancel()
        boundRailProvider = provider
        refreshHasRailContent()
        setRailViewVisible(provider.hasVisibleTabs)
        railVisibilityObserver = provider.addObserver { [weak self] event in
            switch event {
            case let .visibilityChanged(visible):
                self?.setRailViewVisible(visible)
                self?.refreshHasRailContent()
            case .tabsChanged, .visibleCategoriesChanged, .visibleTabIDChanged, .didAppear:
                // 内容集合本身变了（例如全新安装后首个会话注册 `chats` 标签）：
                // 必须重新求值，否则无法把已折叠的 Rail 面板重新挂载起来。
                self?.refreshHasRailContent()
            case .activeTabChanged, .widthChanged:
                break
            }
        }
    }

    /// 依据已绑定的 Rail Provider 重算 `hasRailContent`。
    ///
    /// - Important: 只在值**确实改变**时赋值，避免无意义的
    ///   `objectWillChange` 与视图重建。
    private func refreshHasRailContent() {
        let hasContent = boundRailProvider.map { $0.hasVisibleTabs || $0.hasVisibleSections } ?? false
        guard hasRailContent != hasContent else { return }
        hasRailContent = hasContent
    }

    public override func bindRailViewWidth(
        to provider: any RailViewProviding,
        onResize: @escaping @MainActor (CGFloat) -> Void
    ) {
        railWidthObserver?.cancel()
        railWidthResizeHandler = onResize
        railWidth = provider.railWidth
        railWidthObserver = provider.addObserver { [weak self] event in
            guard case let .widthChanged(width) = event else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.railWidth = width
                self.emitRootViewEvent(.railWidthChanged(width))
            }
        }
    }

    public override func saveRailViewWidth(_ width: CGFloat) {
        railWidthResizeHandler?(width)
    }

    public override func activateContentFooterHeightProfile(
        ownerID: String,
        recommended: ContentFooterHeight,
        store: (any ContentFooterHeightStoring)?
    ) {
        guard !ownerID.isEmpty else { return }
        activeContentFooterHeightOwnerID = ownerID
        activeContentFooterHeightStore = store
        let restoredHeight = store?.loadHeight(ownerID: ownerID) ?? recommended.idealHeight
        let resolvedHeight = recommended.withIdealHeight(recommended.clamped(restoredHeight))
        if contentFooterHeight != resolvedHeight {
            contentFooterHeight = resolvedHeight
            emitRootViewEvent(.contentFooterHeightChanged(contentFooterHeight))
        }
    }

    public override func deactivateContentFooterHeightProfile(ownerID: String) {
        guard activeContentFooterHeightOwnerID == ownerID else { return }
        activeContentFooterHeightOwnerID = nil
        activeContentFooterHeightStore = nil
        if contentFooterHeight != .standard {
            contentFooterHeight = .standard
            emitRootViewEvent(.contentFooterHeightChanged(contentFooterHeight))
        }
    }

    public override func saveCurrentContentFooterHeight(_ height: CGFloat) {
        guard let activeContentFooterHeightOwnerID else { return }
        let resolvedHeight = contentFooterHeight.clamped(height)
        activeContentFooterHeightStore?.saveHeight(resolvedHeight, ownerID: activeContentFooterHeightOwnerID)
        let updatedHeight = contentFooterHeight.withIdealHeight(resolvedHeight)
        if contentFooterHeight != updatedHeight {
            contentFooterHeight = updatedHeight
            emitRootViewEvent(.contentFooterHeightChanged(contentFooterHeight))
        }
    }

    public override func setContentHeaderView(_ view: AnyView?) {
        guard !isSameView(contentHeaderView, view) else { return }
        super.setContentHeaderView(view)
        if Self.verbose {
            Self.logger.debug("\(self.t)set content header view: \(view == nil ? "nil" : "injected")")
        }
    }

    public override func setContentView(_ view: AnyView?) {
        guard !isSameView(contentView, view) else { return }
        super.setContentView(view)
        if Self.verbose {
            Self.logger.debug("\(self.t)set content view: \(view == nil ? "nil" : "injected")")
        }
    }

    public override func setContentFooterView(_ view: AnyView?) {
        guard !isSameView(contentFooterView, view) else { return }
        super.setContentFooterView(view)
        if Self.verbose {
            Self.logger.debug("\(self.t)set content footer view: \(view == nil ? "nil" : "injected")")
        }
    }

    public override func setContentFooterViewHidden(_ hidden: Bool) {
        guard isContentFooterViewHidden != hidden else { return }
        super.setContentFooterViewHidden(hidden)
        if Self.verbose {
            Self.logger.debug("\(self.t)set content footer hidden: \(hidden)")
        }
    }

    public override func setContentViewHidden(_ hidden: Bool) {
        guard isContentViewHidden != hidden else { return }
        super.setContentViewHidden(hidden)
        if Self.verbose {
            Self.logger.debug("\(self.t)set content view hidden: \(hidden)")
        }
    }

    public override func setContentHeaderViewHidden(_ hidden: Bool) {
        guard isContentHeaderViewHidden != hidden else { return }
        super.setContentHeaderViewHidden(hidden)
        if Self.verbose {
            Self.logger.debug("\(self.t)set content header hidden: \(hidden)")
        }
    }

    public override func setTrailingPane(_ pane: RootViewPane?) {
        guard pane !== trailingPane else { return }
        trailingPane = pane
        emitRootViewEvent(.trailingPaneChanged)
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
    /// 导致 App body 重求值后再次装配），重复赋值会在视图更新期间
    /// 触发不必要的刷新并可能形成循环。状态相同即跳过，避免无意义发布。
    ///
    /// 注意：这是保守近似 —— 已注入非 nil 视图后，再次注入任意新视图（含不同
    /// 类型）都会被跳过。Lumi 架构下视图内容更新由视图内部状态驱动（Provider
    /// 的内部状态驱动，无需重新注入新 `AnyView`；若确有
    /// Provider 需要强制替换，可先传 nil 再传新值。
    private func isSameView(_ lhs: AnyView?, _ rhs: AnyView?) -> Bool {
        (lhs == nil) == (rhs == nil)
    }

    public override func makeRootView() -> AnyView {
        if Self.verbose {
            Self.logger.debug("\(self.t)make root view: toolbar=\(self.toolbarView == nil ? "nil" : "set"), activityBar=\(self.activityBarView == nil ? "nil" : "set"), rail=\(self.railView == nil ? "nil" : "set"), content=\(self.contentView == nil ? "nil" : "set"), footer=\(self.contentFooterView == nil ? "nil" : "set")")
        }
        return AnyView(RootOverlayHostView(provider: self))
    }

    // MARK: - 显示条件

    /// 是否存在可渲染的活跃内容。
    ///
    /// 内容插件的容器状态不是根视图渲染的必要条件。ChatPanel 由
    /// ActivityBar + ChatSection 驱动，只要 trailing pane 可见就应正常显示。
    var hasActiveContent: Bool {
        return contentHeaderView != nil
            || contentView != nil
            || (contentFooterView != nil && !isContentFooterViewHidden)
            || trailingPane?.isVisible == true
    }
}

/// Observes the provider's overlay registry and rebuilds the wrapper chain when
/// a plugin adds or removes an overlay after the root view has been assembled.
@MainActor
private struct RootOverlayHostView: View {
    let provider: LumiRootViewProvider
    @State private var observationRevision = 0
    @State private var observerHandle: (any RootViewObserverHandle)?

    var body: some View {
        makeWrappedRoot()
            .id(observationRevision)
            .onAppear {
                guard observerHandle == nil else { return }
                observerHandle = provider.addRootViewObserver { event in
                    guard case .overlaysChanged = event else { return }
                    observationRevision += 1
                }
            }
            .onDisappear {
                observerHandle?.cancel()
                observerHandle = nil
            }
    }

    private func makeWrappedRoot() -> AnyView {
        var root = AnyView(DefaultRootHostView(provider: provider))
        for overlay in provider.overlays {
            root = overlay.wrap(root)
        }
        return root
    }
}

/// Compatibility name for existing Lumi factories and tests.
public typealias DefaultRootViewProvider = LumiRootViewProvider
