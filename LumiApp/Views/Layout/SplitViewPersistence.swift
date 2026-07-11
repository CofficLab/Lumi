import AppKit
import LumiCoreKit
import os
import SuperLogKit
import SwiftUI

// MARK: - 角色与访问层

/// divider 位置的访问层。
///
/// 视图层不直接读写内核或磁盘，而是通过此闭包桥接与 `LumiLayoutState` 交互：
/// - `readInitialPosition`: 从内核状态读取上一次保存的位置（无值时返回 nil，由调用方回退到默认值）
/// - `persist`: 把用户拖拽后的位置写回内核（内核变更会发通知，由插件负责落盘）
///
/// 这样 `SplitDividerPersistenceView`（一个 NSView）无需持有 `ObservableObject`，
/// 也不依赖 SwiftUI 的观察机制，保持与 AppKit 的交互方式不变。
///
/// 两个闭包均标记 `@MainActor`，因为它们最终调用 `LumiLayoutState`（`@MainActor`）的方法。
struct SplitDividerAccess {
    let readInitialPosition: @MainActor () -> CGFloat?
    let persist: @MainActor (CGFloat) -> Void
    /// 用于在日志中描述该角色的可读标签，例如 `railDivider[LumiEditor]`。
    let labelForLog: @MainActor () -> String
}

/// 描述一个分栏 divider 位置的角色，用于在视图层语义化地选择读写哪一类位置。
enum SplitDividerRole {
    case rail(viewContainerID: String)
    case bottomPanel(viewContainerID: String)
    case chatSection(viewContainerID: String, layout: LumiChatSectionLayout)

    /// 基于该角色与内核 `layoutState` 构造读写桥接。
    @MainActor
    func makeAccess(layoutState: LumiLayoutState) -> SplitDividerAccess {
        switch self {
        case let .rail(viewContainerID):
            return SplitDividerAccess(
                readInitialPosition: { layoutState.storedRailDivider(for: viewContainerID) },
                persist: { layoutState.setRailDivider($0, for: viewContainerID) },
                labelForLog: { "railDivider[\(viewContainerID)]" }
            )
        case let .bottomPanel(viewContainerID):
            return SplitDividerAccess(
                readInitialPosition: { layoutState.storedBottomPanelDivider(for: viewContainerID) },
                persist: { layoutState.setBottomPanelDivider($0, for: viewContainerID) },
                labelForLog: { "bottomPanelDivider[\(viewContainerID)]" }
            )
        case let .chatSection(viewContainerID, layout):
            return SplitDividerAccess(
                readInitialPosition: { layoutState.storedChatSectionDivider(for: viewContainerID, layout: layout) },
                persist: { layoutState.setChatSectionDivider($0, for: viewContainerID, layout: layout) },
                labelForLog: { "chatSectionDivider[\(viewContainerID).\(layout.persistenceKeySuffix)]" }
            )
        }
    }

    /// 首次显示且无持久化值时的回退位置（轴向无关，由 split view 自己的 bounds 决定最终生效值）。
    @MainActor
    func defaultPosition() -> CGFloat {
        switch self {
        case .rail:
            return 240
        case .bottomPanel:
            return 400
        case .chatSection(_, let layout):
            return layout.idealWidth
        }
    }

    /// 该角色期望的 NSSplitView 轴向。
    ///
    /// 返回值语义直接对齐 `NSSplitView.isVertical`，供消歧过滤做相等比较。
    /// 注意命名陷阱：`NSSplitView.isVertical == true` 表示**垂直分隔线**（左右分栏，即 SwiftUI 的 HSplitView）；
    /// `== false` 表示水平分隔线（上下分栏，即 VSplitView）。
    ///
    /// 用于在多层嵌套 NSSplitView 中消歧，避免幽灵 NSView 绑错层级：
    /// - `rail` / `chatSection` 挂在 HSplitView 上 → `isVertical == true` → 返回 `true`
    /// - `bottomPanel` 挂在 VSplitView 上 → `isVertical == false` → 返回 `false`
    func expectsVerticalSplit() -> Bool {
        switch self {
        case .rail, .chatSection:
            return true   // HSplitView：左右分栏，分隔线垂直
        case .bottomPanel:
            return false  // VSplitView：上下分栏，分隔线水平
        }
    }

    /// 是否参与"rail / middle / chat"水平三栏宽度日志。
    /// - `rail` / `chatSection`：是
    /// - `bottomPanel`：否（影响的是垂直高度，不在三栏中）
    var participatesInHorizontalThreeColumns: Bool {
        switch self {
        case .rail, .chatSection: return true
        case .bottomPanel: return false
        }
    }
}

// MARK: - 视图包装

/// 把分栏 divider 位置持久化挂到 NSSplitView 旁边的“幽灵” NSView 包装。
///
/// 单一 API 覆盖三种 role；通过静态工厂让调用点读起来自然：
/// ```
/// .background(SplitViewDividerPersistence.rail(layoutState: ..., viewContainerID: ...))
/// .background(SplitViewDividerPersistence.bottomPanel(layoutState: ..., viewContainerID: ...))
/// .background(SplitViewDividerPersistence.chatSection(layoutState: ..., viewContainerID: ..., layout: ...))
/// ```
struct SplitViewDividerPersistence: NSViewRepresentable {
    let layoutState: LumiLayoutState
    let role: SplitDividerRole

    static func rail(layoutState: LumiLayoutState, viewContainerID: String) -> SplitViewDividerPersistence {
        SplitViewDividerPersistence(layoutState: layoutState, role: .rail(viewContainerID: viewContainerID))
    }

    static func bottomPanel(layoutState: LumiLayoutState, viewContainerID: String) -> SplitViewDividerPersistence {
        SplitViewDividerPersistence(layoutState: layoutState, role: .bottomPanel(viewContainerID: viewContainerID))
    }

    static func chatSection(
        layoutState: LumiLayoutState,
        viewContainerID: String,
        layout: LumiChatSectionLayout
    ) -> SplitViewDividerPersistence {
        SplitViewDividerPersistence(
            layoutState: layoutState,
            role: .chatSection(viewContainerID: viewContainerID, layout: layout)
        )
    }

    func makeNSView(context: Context) -> SplitDividerPersistenceView {
        SplitDividerPersistenceView(layoutState: layoutState, role: role)
    }

    func updateNSView(_ nsView: SplitDividerPersistenceView, context: Context) {
        nsView.updateConfiguration(layoutState: layoutState, role: role)
    }

    static func dismantleNSView(_ nsView: SplitDividerPersistenceView, coordinator: ()) {
        nsView.detach()
    }
}

// MARK: - 幽灵 NSView

/// 挂在 NSSplitView 旁边的“幽灵” NSView，负责：
/// 1. 在 attach 时把内核中的持久化 divider 位置应用到 NSSplitView 的 divider 0；
/// 2. 监听 `NSSplitView.didResizeSubviewsNotification`，维护“上次稳定快照”
///    （整体 bounds 尺寸 + divider 位置），**仅在整体尺寸不变但 divider 位置真的变了**
///    时判定为用户拖拽，写回内核并打“拖拽结束”日志。
///
/// ## 设计要点
/// - **不用 will/did 配对**：NotificationCenter 观察者用 `queue: .main` **异步派发**，
///   block 执行时子视图早已移动完毕，`willResize` 读到的“起点”等于 `didResize` 读到的“新位置”，
///   start == new 恒成立，宽度变化被误判为“变化过小”全部跳过。改在 didResize 内自维护
///   `lastObservedBoundsSize` / `lastObservedDividerPosition` 基线，跨事件对比，与时序无关。
/// - **区分“拖 divider” vs “窗口 resize”**：整体 bounds 变了 → 窗口/外层 resize → 只更新基线不持久化；
///   整体 bounds 不变但 divider 位置变了 → 用户拖 divider → 持久化。
/// - **不用 `initialAppliedSize` 黑名单**：v1 的 setPosition 自身会触发 didResize，
///   必须用额外 flag 抑制“初始 apply 被误认为用户拖拽”。v2 用 `isApplyingInitialPosition`
///   局部标志在 setPosition 调用期间屏蔽 will/did，调用结束立即清掉，行为更精确。
/// - **不用 `containingPaneIndex`**：持久化 view 通过 `.background(...)` 挂在
///   NSSplitView 旁边，本身就在 NSSplitView 的视图层级内。读 `position(ofDividerAt: 0)`
///   不需要知道当前 pane 在 split view 中的下标。
/// - **跨 2-pane / 3-pane 兼容**：通过 split view 自身的 `isVertical` + `position(ofDividerAt:)`
///   推算轴向，不依赖外部传入。
@MainActor
final class SplitDividerPersistenceView: NSView, SuperLog {
    nonisolated static let emoji = "📐"
    // 调试期临时打开，便于观察 attach/apply/will/did 全链路。定位完 rail 宽度日志问题后可改回 false。
    nonisolated static let verbose = true
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "split-view.persistence")
    /// 初始 attach 失败时最多重试多少次（每个 runloop 一次）。
    /// 100 × 0.1s = 10s，覆盖 SwiftUI hosting view 装好的极端延迟。
    private static let maxApplyRetryCount = 100

    private var layoutState: LumiLayoutState
    private var role: SplitDividerRole
    private var access: SplitDividerAccess

    private weak var observedSplitView: NSSplitView?
    private var willResizeObserver: NSObjectProtocol?
    private var didResizeObserver: NSObjectProtocol?

    /// 是否已把持久化位置应用到 NSSplitView。`true` 之前所有 will/did 一律跳过。
    private var hasAppliedInitialPosition = false
    /// 当前 apply 调用的重试计数。
    private var applyRetryCount = 0
    /// 正在调用 setPosition 应用初始位置。期间 will/did 一律跳过，避免被误认为“用户拖拽”。
    private var isApplyingInitialPosition = false
    /// 首次成功 attach 后的额外 recheck 计数。
    ///
    /// 解决嵌套布局下 outer HSplitView 早于 inner HSplitView 出现的时序问题：
    /// ghost 第一次 attach 时可能只有 outer 可用，挂错层后 viewDidMoveToWindow 不会再触发，
    /// 只能靠 recheck 周期重新跑 `enclosingSplitView` 找到正确的 inner。
    private var postAttachRecheckCount = 0
    /// post-attach recheck 的最大次数。20 × 0.1s = 2s，覆盖 SwiftUI 嵌套视图构建的极端延迟。
    private static let maxPostAttachRecheckCount = 20

    /// 上一次 didResize 观测到的稳定快照（整体尺寸 + divider 位置）。
    ///
    /// 取代旧版 will/did 配对（`dragStartBoundsSize` / `dragStartPosition`）。
    /// 旧方案依赖 `willResize` 先于 `didResize` 同步触发，但 NotificationCenter
    /// 用 `queue: .main` 异步派发，block 实际执行时子视图早已移动完毕，
    /// 导致 start == new 恒成立，宽度变化被误判为“变化过小”全部跳过。
    /// 新方案在每次 didResize 中自洽地对比“本次快照 vs 上次基线”，
    /// 无需 willResize 配对，异步派发下也正确。
    private var lastObservedBoundsSize: NSSize?
    private var lastObservedDividerPosition: CGFloat?

    init(layoutState: LumiLayoutState, role: SplitDividerRole) {
        self.layoutState = layoutState
        self.role = role
        self.access = role.makeAccess(layoutState: layoutState)
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateConfiguration(layoutState: LumiLayoutState, role: SplitDividerRole) {
        let roleChanged = !rolesEqual(self.role, role)
        self.layoutState = layoutState
        self.role = role
        self.access = role.makeAccess(layoutState: layoutState)
        guard roleChanged else { return }
        // role 变了：重置 apply 状态，等下次 layout 重新挂代理
        hasAppliedInitialPosition = false
        applyRetryCount = 0
        isApplyingInitialPosition = false
        lastObservedBoundsSize = nil
        lastObservedDividerPosition = nil
        postAttachRecheckCount = 0
        if Self.verbose {
            Self.logger.info("\(self.t)config updated, role changed")
        }
        if let split = observedSplitView {
            applyInitialPositionIfPossible(in: split)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if Self.verbose {
            Self.logger.info("\(self.t)view moved to window")
        }
        attachIfPossible()
    }

    func detach() {
        if let willResizeObserver {
            NotificationCenter.default.removeObserver(willResizeObserver)
            self.willResizeObserver = nil
        }
        if let didResizeObserver {
            NotificationCenter.default.removeObserver(didResizeObserver)
            self.didResizeObserver = nil
        }
        observedSplitView = nil
        postAttachRecheckCount = 0
    }

    // MARK: - 挂载

    private func attachIfPossible() {
        guard window != nil else {
            if Self.verbose {
                Self.logger.info("\(self.t)no window yet")
            }
            return
        }
        guard let splitView = enclosingSplitView() else {
            if Self.verbose {
                Self.logger.info("\(self.t)no enclosing split view yet, retry=\(self.applyRetryCount)")
            }
            scheduleRetryAttach()
            return
        }
        guard splitView !== observedSplitView else {
            applyInitialPositionIfPossible(in: splitView)
            schedulePostAttachRecheck()
            return
        }

        observedSplitView = splitView
        hasAppliedInitialPosition = false
        applyRetryCount = 0
        if Self.verbose {
            let id = ObjectIdentifier(splitView).hashValue
            Self.logger.info("\(self.t)attached to split view, isVertical=\(splitView.isVertical), frame=\(splitView.frame.width)x\(splitView.frame.height), id=\(id)")
        }
        applyInitialPositionIfPossible(in: splitView)

        if let willResizeObserver {
            NotificationCenter.default.removeObserver(willResizeObserver)
        }
        if let didResizeObserver {
            NotificationCenter.default.removeObserver(didResizeObserver)
        }

        willResizeObserver = NotificationCenter.default.addObserver(
            forName: NSSplitView.willResizeSubviewsNotification,
            object: splitView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.handleWillResize() }
        }
        didResizeObserver = NotificationCenter.default.addObserver(
            forName: NSSplitView.didResizeSubviewsNotification,
            object: splitView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.handleDidResize() }
        }
        schedulePostAttachRecheck()
    }

    /// 首次 attach 成功后继续 recheck 几次，应对 ghost attach 时嵌套 inner HSplitView
    /// 还没创建的场景（外层先出现、内层后挂上去）。命中正确的层后即稳定。
    private func schedulePostAttachRecheck() {
        guard postAttachRecheckCount < Self.maxPostAttachRecheckCount else {
            if Self.verbose {
                Self.logger.info("\(self.t)post-attach recheck 上限 (\(Self.maxPostAttachRecheckCount)) 已达，停在当前 split view")
            }
            return
        }
        postAttachRecheckCount += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            // view 已从 window 摘下（dismantleNSView）就停
            guard self.window != nil else { return }
            self.attachIfPossible()
        }
    }

    private func scheduleRetryAttach() {
        guard applyRetryCount < Self.maxApplyRetryCount else {
            // 失败时把 superview 链 dump 出来，便于排查 SwiftUI hosting view 嵌套问题
            Self.logger.warning("\(self.t)gave up attaching after \(Self.maxApplyRetryCount) retries; superview chain: \(self.debugSuperviewChain())")
            return
        }
        applyRetryCount += 1
        DispatchQueue.main.async { [weak self] in self?.attachIfPossible() }
    }

    // MARK: - 初始 apply

    private func applyInitialPositionIfPossible(in splitView: NSSplitView) {
        guard !hasAppliedInitialPosition else { return }
        guard splitView.arrangedSubviews.count >= 2 else {
            if Self.verbose {
                Self.logger.info("\(self.t)split view has <2 arrangedSubviews, retry later")
            }
            scheduleRetryApply(in: splitView)
            return
        }

        let totalSize = splitView.isVertical ? splitView.bounds.width : splitView.bounds.height
        guard totalSize > 0 else {
            if Self.verbose {
                Self.logger.info("\(self.t)totalSize is 0, retry later")
            }
            scheduleRetryApply(in: splitView)
            return
        }

        let savedPosition = access.readInitialPosition() ?? role.defaultPosition()
        let maxPosition = max(0, totalSize - splitView.dividerThickness)
        let clampedPosition = min(max(savedPosition, 0), maxPosition)

        if Self.verbose {
            Self.logger.info("\(self.t)applying initial position: saved=\(self.access.readInitialPosition().map { "\($0)" } ?? "nil"), requested=\(savedPosition), target=\(clampedPosition), total=\(totalSize)")
        }

        // setPosition 不能在 layout pass 期间同步调用：viewDidMoveToWindow 等回调恰好
        // 发生在一次布局过程中，setPosition 内部会触发同步 layout，从而重入并产生
        // "not legal to call layoutSubtreeIfNeeded on a view already being laid out" 警告。
        // 故把 setPosition 推迟到当前 runloop 末尾（此时 layout pass 已结束）。
        // 先置 hasAppliedInitialPosition，防止 retry/重复进入；isApplyingInitialPosition
        // 仅在 setPosition 真正执行期间置位，用于屏蔽异步派发的 didResize。
        hasAppliedInitialPosition = true
        let positionToApply = clampedPosition
        isApplyingInitialPosition = true
        DispatchQueue.main.async { [weak self, weak splitView] in
            guard let self, let splitView else {
                self?.isApplyingInitialPosition = false
                return
            }
            splitView.setPosition(positionToApply, ofDividerAt: 0)
            self.isApplyingInitialPosition = false
            if self.access.readInitialPosition() != nil {
                Self.logger.info("\(self.t)applied initial position: \(self.access.labelForLog()) = \(String(format: "%.1f", positionToApply))")
            }
        }
    }

    private func scheduleRetryApply(in splitView: NSSplitView) {
        guard applyRetryCount < Self.maxApplyRetryCount else {
            Self.logger.warning("\(self.t)gave up applying after \(Self.maxApplyRetryCount) retries")
            return
        }
        applyRetryCount += 1
        DispatchQueue.main.async { [weak self, weak splitView] in
            guard let self, let splitView else { return }
            self.applyInitialPositionIfPossible(in: splitView)
        }
    }

    // MARK: - will/did 配对

    private func handleWillResize() {
        // 旧版在此记录起点供 didResize 配对判断，但 NotificationCenter 用
        // `queue: .main` 异步派发，block 执行时子视图早已移动完毕，
        // 读到的“起点”已是新位置 → start == new → 永远判定为“变化过小”。
        // 新方案改在 didResize 内用自维护基线对比，不再依赖 willResize 的时序。
        // 保留方法以免调用点改动；如不再需要可安全删除。
    }

    private func handleDidResize() {
        guard hasAppliedInitialPosition,
              !isApplyingInitialPosition,
              let splitView = observedSplitView
        else {
            if Self.verbose {
                let reason = !hasAppliedInitialPosition ? "初始位置未应用"
                    : isApplyingInitialPosition ? "正在应用初始位置"
                    : "未挂载到 splitView"
                Self.logger.info("\(self.t)didResize 跳过: \(reason)")
            }
            return
        }

        // 持续把 panel column 宽度同步给 layout state，供其"三栏宽度"日志推算 middle。
        // 任何一次 didResize（窗口 resize / 拖 divider）都更新，保证下次日志拿到的是最新值。
        // bottomPanel 不参与水平三栏，跳过。
        if let id = currentViewContainerID, role.participatesInHorizontalThreeColumns {
            let panelColumnWidth = computeCurrentPanelColumnWidth(in: splitView)
            if panelColumnWidth > 0 {
                layoutState.setPanelColumnWidth(panelColumnWidth, for: id)
            }
        }

        let currentBounds = splitView.bounds.size
        let currentPosition = dividerPosition(at: 0, in: splitView)

        let prevBounds = lastObservedBoundsSize
        let prevPosition = lastObservedDividerPosition

        // 始终刷新基线：无论本次是否持久化，下一轮对比都以“当前”为参照。
        defer {
            lastObservedBoundsSize = currentBounds
            lastObservedDividerPosition = currentPosition
        }

        // 首次观测到稳定状态：只记录基线，不做任何判断（没有“上一次”可比）。
        guard let prevBounds, let prevPosition else {
            if Self.verbose {
                Self.logger.info("\(self.t)didResize 建立基线: pos=\(currentPosition), bounds=\(currentBounds.width)x\(currentBounds.height)")
            }
            return
        }

        // 窗口 / split view 自身 resize：整体尺寸变了 → 用户在缩放窗口，不是拖 divider → 跳过。
        if currentBounds != prevBounds { return }

        // 尺寸不变但 divider 位置也没变 → 无意义抖动 → 跳过。
        let delta = currentPosition - prevPosition
        if abs(delta) < 0.5 { return }

        // 尺寸不变 + divider 位置变了 → 用户在拖 divider → 持久化并打日志。
        access.persist(currentPosition)
        // 日志始终输出（不依赖 verbose），便于人工/QA 直接观察到拖拽结果。
        let label = access.labelForLog()
        let oldText = String(format: "%.1f", prevPosition)
        let newText = String(format: "%.1f", currentPosition)
        Self.logger.info("\(self.t)拖拽结束: \(label) = \(newText) (旧值: \(oldText))")
    }

    // MARK: - 工具

    private func rolesEqual(_ lhs: SplitDividerRole, _ rhs: SplitDividerRole) -> Bool {
        switch (lhs, rhs) {
        case (.rail(let a), .rail(let b)): return a == b
        case (.bottomPanel(let a), .bottomPanel(let b)): return a == b
        case (.chatSection(let a1, let a2), .chatSection(let b1, let b2)):
            return a1 == b1 && a2 == b2
        default: return false
        }
    }

    /// 找到与本 view 关联的 NSSplitView。
    ///
    /// 找到与本 view 关联的 NSSplitView。
    ///
    /// ## 为什么不能只走 superview 链
    /// SwiftUI 的 `.background(NSViewRepresentable)` 挂在 `HSplitView`/`VSplitView`
    /// **类型本身**上时（如 `VSplitView { ... }.background(ghost)`），ghost 会被渲染进
    /// `NSHostingView` 的背景层，而真正的 `NSSplitView` 是它的**兄弟节点**，不在祖先链里。
    /// 实测 chatSection/bottomPanel 的 ghost 落点为：
    ///
    ///     SplitDividerPersistenceView <- PlatformViewHost <- NSHostingView <- NSThemeFrame
    ///
    /// 链中没有任何 NSSplitView。只有当 `.background()` 挂在 split view 的**子 pane**
    /// 上时（rail 的做法），ghost 才在 split view 子树内，superview 链才走得到。
    ///
    /// ## 嵌套消歧（关键）
    /// Lumi 的布局是**三层嵌套** NSSplitView：
    ///
    ///     HSplitView [A] (Panel | Chat)        ← chatSection（水平，最外层）
    ///       └ PanelColumnView
    ///           └ HSplitView [B] (Rail | Panel) ← rail（水平，最内层 HSplitView）
    ///               └ PanelWorkspaceView
    ///                   └ VSplitView [C] (content | bottom) ← bottomPanel（垂直）
    ///
    /// **绝不能**对所有 role 一律"取面积最小"——A 和 B 的 ghost 中心都同时被 A 和 B "包含"
    /// （B 整体嵌在 A 内），最小那条规则对 rail 蒙对、对 chatSection 蒙错。选错层会导致
    /// divider 语义错位：A.divider0 是聊天区宽度、B.divider0 是 rail 宽度，两者不能互换。
    ///
    /// ## 三步定位法
    /// 1. **轴向过滤**：`bottomPanel` 只要 `isVertical == false`（VSplitView）；
    ///    `rail` / `chatSection` 只要 `isVertical == true`（HSplitView）。
    ///    这一步把三层嵌套里错层级的候选直接剔除（rail 不可能盯到 bottomPanel 那层）。
    /// 2. **几何包含**：把每个候选 split view 的 frame 转到 window 坐标，保留**包含 ghost 中心点**的候选。
    ///    ghost 是背景层，其中心点必然落在所属 split view 内部。
    /// 3. **按 role 选层级**：在几何上被包含的候选里——
    ///    - `chatSection` 取面积**最大**的（最外层 A）
    ///    - `rail` / `bottomPanel` 取面积**最小**的（最内层 B / C）
    ///    候选唯一时 min/max 退化为同一结果，无副作用。
    private func enclosingSplitView() -> NSSplitView? {
        // Step 1: 在整个 window 视图树里 BFS 收集所有 NSSplitView 候选。
        // 只走祖先链会漏掉兄弟节点的 NSSplitView（见上文 hosting view 兄弟场景）。
        guard let rootView = window?.contentView else { return nil }
        var allCandidates: [NSSplitView] = []
        var queue: [NSView] = [rootView]
        while !queue.isEmpty {
            let view = queue.removeFirst()
            if let splitView = view as? NSSplitView {
                allCandidates.append(splitView)
            }
            queue.append(contentsOf: view.subviews)
        }
        guard !allCandidates.isEmpty else { return nil }

        // Step 2: 按 role 的轴向要求过滤。
        if Self.verbose {
            let dump = allCandidates.map { sv -> String in
                let f = sv.superview?.convert(sv.frame, to: nil) ?? sv.frame
                let id = ObjectIdentifier(sv).hashValue
                return "[v=\(sv.isVertical),f=\(Int(f.width))x\(Int(f.height))@(\(Int(f.minX)),\(Int(f.minY))),id=\(id)]"
            }.joined(separator: " ")
            let ghostCenter = self.convert(NSPoint(x: self.bounds.midX, y: self.bounds.midY), to: nil)
            Self.logger.info("\(self.t)候选数=\(allCandidates.count), ghostCenter=(\(Int(ghostCenter.x)),\(Int(ghostCenter.y))), ghostBounds=\(Int(self.bounds.width))x\(Int(self.bounds.height)): \(dump)")
        }
        let wantsVertical = role.expectsVerticalSplit()
        let orientationMatches = allCandidates.filter { $0.isVertical == wantsVertical }

        // 轴向匹配为空时不勉强：返回 nil 触发 retry，而不是 fallback 错绑。
        // （旧版 fallback 到最近的任意 split view 正是 bottomPanel 错绑 HSplitView 的根因。）
        guard !orientationMatches.isEmpty else { return nil }

        // Step 3: 保留包含 ghost 中心点的候选，再按 role 选层级。
        // 关键：rail 和 chatSection 的 ghost 中心都会被 A 和 B 同时"包含"（B 整体嵌在 A 内），
        // 不能对所有 role 一律"取最小"——chatSection 实际挂在外层 A 上，要取最大；rail 挂在内层 B 上，要取最小。
        // 选错层级会导致 divider 语义错位：A.divider0 = 聊天区宽度，B.divider0 = rail 宽度。
        let ghostCenterInWindow = convert(NSPoint(x: bounds.midX, y: bounds.midY), to: nil)
        // ghost 刚加入 window 时 bounds 还是 .zero，中心点退化为 (0,0)，无法可靠定位。
        // 此时按 role 取兜底：chatSection 取最大（最外层），rail/bottomPanel 取最小（最内层）。
        guard ghostCenterInWindow.x != 0 || ghostCenterInWindow.y != 0 else {
            return pickByRole(from: orientationMatches)
        }
        let containing = orientationMatches.filter { sv in
            let frameInWindow = sv.superview?.convert(sv.frame, to: nil) ?? sv.frame
            return frameInWindow.contains(ghostCenterInWindow)
        }
        let resolved = containing.isEmpty ? orientationMatches : containing
        return pickByRole(from: resolved)
    }

    /// 按 role 在候选 split views 中挑出正确的那一层。
    /// - chatSection：挂在最外层 A（Panel | Chat）上 → 取面积最大的
    /// - rail / bottomPanel：挂在内层 B（Rail | Panel）或 C（content | bottom）上 → 取面积最小的
    /// 候选只有 1 个时 min/max 退化为同一结果，无副作用。
    private func pickByRole(from candidates: [NSSplitView]) -> NSSplitView? {
        switch role {
        case .chatSection:
            return candidates.max(by: { area($0.bounds) < area($1.bounds) })
        case .rail, .bottomPanel:
            return candidates.min(by: { area($0.bounds) < area($1.bounds) })
        }
    }

    private func area(_ rect: NSRect) -> CGFloat {
        max(0, rect.width) * max(0, rect.height)
    }

    /// 提取当前 role 关联的视图容器 ID，用于把 panel column 宽度同步给 layout state。
    private var currentViewContainerID: String? {
        switch role {
        case .rail(let id), .bottomPanel(let id), .chatSection(let id, _):
            return id
        }
    }

    /// 计算当前 split view 视角下的 panel column 宽度（= rail 所在 HSplitView 的总宽度）。
    ///
    /// - `rail` ghost 挂在 panel column 内部的 HSplitView（B）上 → `B.bounds.width` 就是 panel column。
    /// - `chatSection` ghost 挂在 panel | chat 的外层 HSplitView（A）上 → `A.arrangedSubviews[0]` 是 panel column。
    /// - `bottomPanel` 调到这里时上层 caller 应当已经过滤掉（`participatesInHorizontalThreeColumns == false`），返回 0 兜底。
    private func computeCurrentPanelColumnWidth(in splitView: NSSplitView) -> CGFloat {
        switch role {
        case .rail:
            return splitView.bounds.width
        case .chatSection:
            guard let firstPane = splitView.arrangedSubviews.first else { return 0 }
            return firstPane.frame.width
        case .bottomPanel:
            return 0
        }
    }

    /// 调试用：把 superview 链打印成 “view1 <- view2 <- view3” 形式。
    /// 仅在 verbose 开启 + attach 失败时调用，避免日常日志噪音。
    private func debugSuperviewChain() -> String {
        var parts: [String] = []
        var current: NSView? = self
        var depth = 0
        while let view = current, depth < 8 {
            let typeName = String(describing: type(of: view))
            let isSplit = view is NSSplitView ? " [NSSplitView]" : ""
            parts.append("\(typeName)\(isSplit)")
            current = view.superview
            depth += 1
        }
        return parts.joined(separator: " <- ")
    }

    /// 读取 divider 的当前位置。NSSplitView 没有提供 getter（只有 setter `setPosition`），
    /// 从 `arrangedSubviews[i].frame` 推算：divider i 在 HSplitView 里 = pane i 的 maxX，
    /// 在 VSplitView 里 = pane i 的 maxY。
    private func dividerPosition(at index: Int, in splitView: NSSplitView) -> CGFloat {
        guard index >= 0, index < splitView.arrangedSubviews.count else { return 0 }
        let frame = splitView.arrangedSubviews[index].frame
        return splitView.isVertical ? frame.maxX : frame.maxY
    }
}
