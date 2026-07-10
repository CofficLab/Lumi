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
}

// MARK: - 视图包装

/// 把分栏 divider 位置持久化挂到 NSSplitView 旁边的"幽灵" NSView 包装。
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

/// 挂在 NSSplitView 旁边的"幽灵" NSView，负责：
/// 1. 在 attach 时把内核中的持久化 divider 位置应用到 NSSplitView 的 divider 0；
/// 2. 监听 NSSplitView 的 `will/didResizeSubviewsNotification` 配对，
///    **仅在用户拖拽 divider（bounds 未变）且位置真的变了**时写回内核并打"拖拽结束"日志。
///
/// ## 设计要点
/// - **不用 150ms 防抖计时器**：v1 的 `DispatchQueue.main.asyncAfter` 是 hack，
///   没法区分"用户按住思考中"和"用户已松手"。v2 直接用 NSSplitView 的 will/did 配对
///   + bounds 尺寸对比，这是 NSSplitView 自己区分"用户拖 divider"和"系统/窗口 resize"
///   的官方机制。
/// - **不用 `initialAppliedSize` 黑名单**：v1 的 setPosition 自身会触发 didResize，
///   必须用额外 flag 抑制"初始 apply 被误认为用户拖拽"。v2 用 `isApplyingInitialPosition`
///   局部标志在 setPosition 调用期间屏蔽 will/did，调用结束立即清掉，行为更精确。
/// - **不用 `containingPaneIndex`**：持久化 view 通过 `.background(...)` 挂在
///   NSSplitView 旁边，本身就在 NSSplitView 的视图层级内。读 `position(ofDividerAt: 0)`
///   不需要知道当前 pane 在 split view 中的下标。
/// - **跨 2-pane / 3-pane 兼容**：通过 split view 自身的 `isVertical` + `position(ofDividerAt:)`
///   推算轴向，不依赖外部传入。
@MainActor
final class SplitDividerPersistenceView: NSView, SuperLog {
    nonisolated static let emoji = "📐"
    nonisolated static let verbose = false
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "split-view.persistence")
    /// 初始 apply 失败时最多重试多少次（每个 runloop 一次）。超过后放弃 + 警告日志。
    private static let maxApplyRetryCount = 20

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
    /// 正在调用 setPosition 应用初始位置。期间 will/did 一律跳过，避免被误认为"用户拖拽"。
    private var isApplyingInitialPosition = false

    /// will 阶段记录：用于在 did 阶段判断"是否用户拖拽"。
    private var dragStartBoundsSize: NSSize?
    private var dragStartPosition: CGFloat?

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
        dragStartBoundsSize = nil
        dragStartPosition = nil
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
            return
        }

        observedSplitView = splitView
        hasAppliedInitialPosition = false
        applyRetryCount = 0
        if Self.verbose {
            Self.logger.info("\(self.t)attached to split view, isVertical=\(splitView.isVertical)")
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
    }

    private func scheduleRetryAttach() {
        guard applyRetryCount < Self.maxApplyRetryCount else {
            Self.logger.warning("\(self.t)gave up attaching after \(Self.maxApplyRetryCount) retries")
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

        // 同步 setPosition：will/did 在此期间会触发，isApplyingInitialPosition 标志屏蔽它们。
        isApplyingInitialPosition = true
        splitView.setPosition(clampedPosition, ofDividerAt: 0)
        splitView.layoutSubtreeIfNeeded()
        isApplyingInitialPosition = false
        hasAppliedInitialPosition = true

        // 日志：仅在确实不是默认值时显式记录，便于 QA 验证。
        if access.readInitialPosition() != nil {
            Self.logger.info("\(self.t)applied initial position: \(self.access.labelForLog()) = \(String(format: "%.1f", clampedPosition))")
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
        guard hasAppliedInitialPosition,
              !isApplyingInitialPosition,
              let splitView = observedSplitView
        else { return }
        dragStartBoundsSize = splitView.bounds.size
        dragStartPosition = dividerPosition(at: 0, in: splitView)
    }

    private func handleDidResize() {
        guard hasAppliedInitialPosition,
              !isApplyingInitialPosition,
              let splitView = observedSplitView,
              let startBounds = dragStartBoundsSize,
              let startPosition = dragStartPosition
        else { return }

        defer {
            dragStartBoundsSize = nil
            dragStartPosition = nil
        }

        // 窗口 / split view 自身 resize：bounds 尺寸变了，不是用户拖 divider → 跳过。
        if splitView.bounds.size != startBounds { return }

        let newPosition = dividerPosition(at: 0, in: splitView)
        if abs(newPosition - startPosition) < 0.5 { return }

        access.persist(newPosition)
        // 日志始终输出（不依赖 verbose），便于人工/QA 直接观察到拖拽结果。
        let label = access.labelForLog()
        let oldText = String(format: "%.1f", startPosition)
        let newText = String(format: "%.1f", newPosition)
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

    private func enclosingSplitView() -> NSSplitView? {
        var current = superview
        while let view = current {
            if let splitView = view as? NSSplitView {
                return splitView
            }
            current = view.superview
        }
        return nil
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
