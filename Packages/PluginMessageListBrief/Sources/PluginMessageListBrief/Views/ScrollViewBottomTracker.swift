import AppKit
import SwiftUI

/// 通过观察底层 `NSScrollView` 的滚动位置来判断「用户是否停在列表底部」，
/// **完全替代** SwiftUI 的 `GeometryReader` + `PreferenceKey` 方案。
///
/// ## 为什么需要它
///
/// 旧方案在 `LazyVStack` 末尾挂一个 `GeometryReader { Color.clear.preference(...) }`，
/// 报告锚点的全局 maxY。在流式场景下（助手回复行高随 token 连续增长），这个锚点的
/// 全局坐标**每帧都在变**，导致 LazyStack 永不收敛 → 主线程 100% CPU 活锁。
///
/// 本类型把「是否在底部」的判定从 SwiftUI 布局/偏好系统里**完全剥离**，改为由
/// AppKit 的 `NSClipView.boundsDidChangeNotification` 驱动（仅在滚动时触发，
/// 流式行高度变化不会触发），彻底切断反馈环。
///
/// ## 线程与 invalidation
///
/// 观察者在主队列回调；闭包写入的内容（`AtBottomBox`）刻意不实现 `ObservableObject`，
/// 因此**不会**触发 SwiftUI invalidation —— 这是切断反馈环的关键之一。
///
/// ## 布局影响
///
/// `makeNSView` 返回一个零尺寸、不参与布局的 NSView，仅用于拿到 window 后向上
/// 查找 `enclosingScrollView`。它不会贡献任何尺寸或参与 SwiftUI 的尺寸协商。
@MainActor
final class ScrollViewBottomController {
    struct Snapshot: Equatable {
        let documentHeight: CGFloat
        let visibleHeight: CGFloat
        let offsetY: CGFloat
    }

    private weak var scrollView: NSScrollView?

    var isAttached: Bool { scrollView != nil }

    fileprivate func attach(to scrollView: NSScrollView) {
        self.scrollView = scrollView
    }

    fileprivate func detach(from scrollView: NSScrollView) {
        guard self.scrollView === scrollView else { return }
        self.scrollView = nil
    }

    /// 钉住底层滚动视图的真实 document 底边，并返回当前几何快照。
    /// SwiftUI proxy 可能使用尚未完成的 List 行布局；直接调整 clip view
    /// 可以让调用方在 document 高度继续增长时重复收敛到真正的底部。
    func pinToBottom() -> Snapshot? {
        guard let scrollView,
              let documentView = scrollView.documentView else { return nil }

        let clipView = scrollView.contentView
        let documentHeight = documentView.bounds.height
        let visibleHeight = clipView.bounds.height
        guard documentHeight.isFinite,
              visibleHeight.isFinite,
              visibleHeight > 0,
              documentHeight < 10_000_000 else { return nil }

        let maxOffsetY = max(0, documentHeight - visibleHeight)
        var bounds = clipView.bounds
        bounds.origin.y = maxOffsetY
        clipView.bounds = bounds
        scrollView.reflectScrolledClipView(clipView)

        return Snapshot(
            documentHeight: documentHeight,
            visibleHeight: visibleHeight,
            offsetY: clipView.bounds.origin.y
        )
    }
}

struct ScrollViewBottomTracker: NSViewRepresentable {
    /// 「是否在底部」布尔值翻转时回调。仅在真正翻转时调用，避免高频无意义触发。
    let onChange: (Bool) -> Void
    /// 提供给滚动协调器的底层滚动控制器，不参与 SwiftUI 布局。
    let controller: ScrollViewBottomController?
    /// 可视区域高度变化时回调，用于计算发送后的尾部留白。
    let onViewportHeightChange: (CGFloat) -> Void
    /// Live-resize 结束时回调，参数为 resize **开始时**是否在底部。
    /// 宿主据此决定底部场景滚到底部（scrollTick）、非底部场景由 tracker 内部恢复 offset。
    var onLiveResizeEnd: ((Bool) -> Void)?

    init(
        onChange: @escaping (Bool) -> Void,
        controller: ScrollViewBottomController? = nil,
        onViewportHeightChange: @escaping (CGFloat) -> Void = { _ in },
        onLiveResizeEnd: ((Bool) -> Void)? = nil
    ) {
        self.onChange = onChange
        self.controller = controller
        self.onViewportHeightChange = onViewportHeightChange
        self.onLiveResizeEnd = onLiveResizeEnd
    }

    func makeNSView(context: Context) -> TrackerView {
        let view = TrackerView()
        view.bottomController = controller
        view.onChange = { [weak coordinator = context.coordinator] atBottom in
            coordinator?.onChange(atBottom)
        }
        view.onViewportHeightChange = { [weak coordinator = context.coordinator] height in
            coordinator?.onViewportHeightChange(height)
        }
        view.onLiveResizeEnd = { [weak coordinator = context.coordinator] wasAtBottom in
            coordinator?.onLiveResizeEnd?(wasAtBottom)
        }
        return view
    }

    func updateNSView(_ nsView: TrackerView, context: Context) {
        // 故意不做任何尺寸/几何相关工作 —— 这里一旦触碰布局就会重新进入
        // SwiftUI 的尺寸协商，可能复活反馈环。仅同步回调句柄。
        context.coordinator.onChange = onChange
        context.coordinator.onViewportHeightChange = onViewportHeightChange
        context.coordinator.onLiveResizeEnd = onLiveResizeEnd
        nsView.bottomController = controller
    }

    static func dismantleNSView(_ nsView: TrackerView, coordinator: Coordinator) {
        nsView.stopObserving()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onChange: onChange,
            onViewportHeightChange: onViewportHeightChange,
            onLiveResizeEnd: onLiveResizeEnd
        )
    }

    final class Coordinator {
        var onChange: (Bool) -> Void
        var onViewportHeightChange: (CGFloat) -> Void
        var onLiveResizeEnd: ((Bool) -> Void)?
        init(
            onChange: @escaping (Bool) -> Void,
            onViewportHeightChange: @escaping (CGFloat) -> Void,
            onLiveResizeEnd: ((Bool) -> Void)?
        ) {
            self.onChange = onChange
            self.onViewportHeightChange = onViewportHeightChange
            self.onLiveResizeEnd = onLiveResizeEnd
        }
    }
}

/// 承载观察逻辑的 NSView。零尺寸、不绘制、不参与布局尺寸协商。
@MainActor
final class TrackerView: NSView {
    fileprivate var onChange: ((Bool) -> Void)?
    fileprivate var onViewportHeightChange: ((CGFloat) -> Void)?
    fileprivate var onLiveResizeEnd: ((Bool) -> Void)?
    fileprivate var bottomController: ScrollViewBottomController?
    private var observation: NSObjectProtocol?
    private weak var observedScrollView: NSScrollView?
    /// 上一次报告的「是否在底部」，用于迟滞判定、避免无谓回调。
    private var lastAtBottom: Bool = true
    private var lastVisibleHeight: CGFloat = 0
    /// Layout callbacks must not synchronously mutate SwiftUI state while
    /// AppKit is laying out the hosting view. Coalesce the latest viewport
    /// height and deliver it on the next main-actor turn instead.
    private var pendingViewportHeight: CGFloat?
    private var viewportHeightUpdateTask: Task<Void, Never>?

    // MARK: - Live-resize 恢复

    /// resize 开始时记录的 contentOffset（仅非底部场景用于松手后恢复阅读位置）。
    private var savedOriginY: CGFloat?
    /// resize 开始时是否在底部。
    private var resizeStartedAtBottom: Bool = false
    /// 底部场景：resize 结束后是否正在执行「持续钉底」恢复。
    ///
    /// 为 true 时，`reevaluate()` 被抑制 —— 防止 lazy materialize 导致的
    /// documentView 高度增长被误判为「离开底部」，也防止恢复过程中
    /// `onChange(false)` 把 `atBottomBox` 置为 false 后，恢复结束无人
    /// 再把它翻回 true，导致后续流式跟随滚动被永久关闭。
    private var isRestoringAfterResize = false
    /// 非底部场景：松手后多帧恢复计数。
    private var restoreAttempts = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: .zero)
        // 不绘制、不参与命中测试，纯粹作为「挂在视图树里用来找 scrollView」的锚点。
        wantsLayer = false
    }

    deinit {
        viewportHeightUpdateTask?.cancel()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            attachIfNeeded()
        } else {
            stopObserving()
        }
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        attachIfNeeded()
    }

    override func layout() {
        super.layout()
        // The tracker is installed as a SwiftUI background and may be laid out
        // after it first enters the window. Retry here so the spatial lookup
        // sees the final panel position without falling back to another pane.
        attachIfNeeded()
    }

    // MARK: - Live-resize 检测（NSResponder 方法，不依赖通知）

    override func viewWillStartLiveResize() {
        super.viewWillStartLiveResize()
        saveOffsetBeforeResize()
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        beginRestoreAfterResize()
    }

    private func attachIfNeeded() {
        guard observation == nil else { return }
        // 优先用 enclosingScrollView（tracker 在 ScrollView 内部时）。
        // 兜底：从 window.contentView 递归查找 NSScrollView（tracker 挂在
        // .background 上时落在容器层，不在 NSScrollView 内部）。
        let scrollView = findScrollView()
        guard let scrollView, scrollView !== observedScrollView else { return }

        stopObserving()
        observedScrollView = scrollView
        bottomController?.attach(to: scrollView)
        let clipView = scrollView.contentView
        // postsBoundsChangedNotifications 默认对 NSClipView 为 true，显式确保。
        clipView.postsBoundsChangedNotifications = true
        observation = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self] _ in
            // NotificationCenter 回调不在 MainActor 上下文里，dispatch 回主线程。
            Task { @MainActor [weak self] in
                self?.reevaluate()
            }
        }
        // 附着后立刻评估一次，把初始状态同步给回调。
        reevaluate()
    }

    /// 从当前视图位置查找 NSScrollView。
    private func findScrollView() -> NSScrollView? {
        if let sv = enclosingScrollView {
            return sv
        }
        guard let rootView = window?.contentView else { return nil }
        // A background NSView is not always descended from the List's
        // NSScrollView. Never choose a scroll view by document height: another
        // pane (for example the conversation rail) can legitimately be larger.
        // Instead, bind only to the scroll view whose viewport contains this
        // tracker anchor point.
        let anchorPoint = convert(NSPoint.zero, to: nil)
        return Self.findScrollView(containing: anchorPoint, in: rootView)
    }

    /// 递归查找包含 tracker 锚点的 NSScrollView。
    ///
    /// `List` 和会话侧栏都是窗口级 NSScrollView；按 document 高度选择会
    /// 把消息列表的 tracker 绑定到侧栏。空间命中保证 tracker 只控制自己
    /// 所在的面板。
    private static func findScrollView(containing point: NSPoint, in view: NSView) -> NSScrollView? {
        var match: NSScrollView?

        func visit(_ v: NSView) {
            if let sv = v as? NSScrollView {
                let viewport = sv.convert(sv.bounds, to: nil)
                if viewport.contains(point) {
                    match = sv
                }
                return // NSScrollView 的子视图不再深入（避免找到内部的 clipView 等）
            }
            for sub in v.subviews {
                if match != nil { return }
                visit(sub)
            }
        }
        visit(view)
        return match
    }

    fileprivate func stopObserving() {
        viewportHeightUpdateTask?.cancel()
        viewportHeightUpdateTask = nil
        pendingViewportHeight = nil
        if let observation {
            NotificationCenter.default.removeObserver(observation)
            self.observation = nil
        }
        if let observedScrollView {
            bottomController?.detach(from: observedScrollView)
        }
        observedScrollView = nil
    }

    // MARK: - 底部判定（迟滞带）

    // MARK: - Live-resize 恢复实现

    private func saveOffsetBeforeResize() {
        let sv = observedScrollView ?? enclosingScrollView
        guard let scrollView = sv else { return }
        resizeStartedAtBottom = lastAtBottom
        savedOriginY = scrollView.contentView.bounds.origin.y
    }

    private func beginRestoreAfterResize() {
        guard savedOriginY != nil else { return }
        if resizeStartedAtBottom {
            // 底部场景：由本类型直接在 AppKit 层持续钉底，直到几何稳定。
            //
            // 为什么不交给宿主的 proxy.scrollTo(bottomAnchor) 重试循环：
            // proxy.scrollTo 对 List 末尾的 Color.clear 锚点是「按需
            // materialize + 滚动到当前坐标」，但富文本行是逐帧/按需 materialize
            // 的，documentView 高度在 resize 结束后的几百毫秒内持续增长。
            // 固定次数的 scrollTo 重试只能追到「当时」的底部。改为：
            // suppress onChange，逐帧把 contentOffset 钉到当前 documentView
            // 底部，直到几何连续多帧稳定，才真正落地。
            isRestoringAfterResize = true
            suppressReevaluateDuringRestore()
            onLiveResizeEnd?(true)
            pinToBottomUntilStable()
        } else {
            // 非底部场景：tracker 在 AppKit 层恢复 contentOffset。
            onLiveResizeEnd?(false)
            restoreAttempts = 0
            scheduleRestore()
        }
    }

    /// 底部场景：逐帧把 contentOffset 钉到 documentView 底部，
    /// 直到几何（高度 + 钉底后的 offset）连续多帧不再变化。
    private func pinToBottomUntilStable() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            // 等 LiveResizeFrozenView 恢复真实宿主并应用最终宽度。
            // 80ms 足够覆盖这一帧 + 后续几帧的 initial layout。
            try? await Task.sleep(nanoseconds: 80_000_000)

            var lastHeight: CGFloat = -1
            var lastOffset: CGFloat = -1
            var stableCount = 0
            // 最多尝试 40 帧 × 80ms = 3.2s，覆盖超长对话的 lazy materialize。
            for _ in 0..<40 {
                guard self.isRestoringAfterResize else { return }
                guard let scrollView = self.observedScrollView ?? self.enclosingScrollView,
                      let documentView = scrollView.documentView else { break }

                let clipView = scrollView.contentView
                let documentHeight = documentView.bounds.height
                let visibleHeight = clipView.bounds.height
                let maxOffset = max(0, documentHeight - visibleHeight)

                guard documentHeight.isFinite, visibleHeight.isFinite,
                      visibleHeight > 0 else { break }

                // 直接写 clipView.bounds 后，必须调 reflectScrolledClipView 让
                // NSScrollView 同步内部状态（滚动条/缓存），否则写入可能被下一次
                // layout 覆盖回去。
                var newBounds = clipView.bounds
                newBounds.origin.y = maxOffset
                clipView.bounds = newBounds
                scrollView.reflectScrolledClipView(clipView)

                // 几何稳定 = documentView 高度不再变 且 钉底后的 offset 也不再变。
                // 任一还在变，说明 lazy materialize 尚未完成，继续钉。
                if abs(documentHeight - lastHeight) < 1.0,
                   abs(maxOffset - lastOffset) < 1.0 {
                    stableCount += 1
                    // 连续 4 帧稳定才认为真正落地，避免偶发一帧的「假稳定」。
                    if stableCount >= 4 { break }
                } else {
                    stableCount = 0
                }
                lastHeight = documentHeight
                lastOffset = maxOffset

                try? await Task.sleep(nanoseconds: 80_000_000)
            }

            self.finishBottomRestore()
        }
    }

    /// 底部恢复落地：解除 suppress，把判定重置回「在底部」并通知宿主，
    /// 确保后续流式跟随滚动（atBottomBox == true）正常工作。
    private func finishBottomRestore() {
        isRestoringAfterResize = false
        savedOriginY = nil
        // 主动把状态翻回 true 并通知宿主 —— 即使恢复过程中曾（被 suppress）
        // 偏离过底部，落地后语义上用户仍应被视为「在底部」。
        if !lastAtBottom {
            lastAtBottom = true
            onChange?(true)
        }
        // 再强制评估一次当前真实几何，确保 lastAtBottom 与实际一致。
        reevaluate()
    }

    /// 恢复期间抑制 reevaluate，防止 lazy materialize 的高度增长被误判
    /// 为「离开底部」而翻转 onChange / 污染 atBottomBox。
    private func suppressReevaluateDuringRestore() {
        // 占位：实际的 suppress 通过在 reevaluate 开头检查 isRestoringAfterResize 实现。
    }

    // MARK: - 非底部场景：contentOffset 恢复

    private func scheduleRestore() {
        guard restoreAttempts < 10 else {
            savedOriginY = nil
            return
        }
        restoreAttempts += 1
        DispatchQueue.main.async { [weak self] in
            self?.restoreOnce()
        }
    }

    private func restoreOnce() {
        // 仅用于非底部场景（resizeStartedAtBottom == false）。
        guard let scrollView = observedScrollView ?? enclosingScrollView,
              let targetY = savedOriginY else { return }
        let clipView = scrollView.contentView
        var bounds = clipView.bounds
        let documentHeight = scrollView.documentView?.bounds.height ?? bounds.height
        let maxOriginY = max(0, documentHeight - bounds.height)
        // 恢复到记录的 offset，夹紧到合法范围。
        bounds.origin.y = min(max(targetY, 0), maxOriginY)

        let currentY = clipView.bounds.origin.y
        if abs(currentY - bounds.origin.y) < 0.5 {
            clipView.bounds = bounds
            savedOriginY = nil
            return
        }
        clipView.bounds = bounds
        scheduleRestore()
    }

    private func reevaluate() {
        // 底部恢复期间完全抑制判定：lazy materialize 导致的高度增长会
        // 让 distance 暂时 > tolerance，若此时翻转 onChange(false)，会
        // 污染 atBottomBox，且恢复结束后无人把它翻回 true。
        guard !isRestoringAfterResize else { return }
        guard let scrollView = observedScrollView,
              let documentView = scrollView.documentView else { return }
        let documentHeight = documentView.bounds.height
        let visibleHeight = scrollView.contentView.bounds.height
        let offsetY = scrollView.contentView.bounds.origin.y
        guard documentHeight.isFinite, visibleHeight.isFinite,
              documentHeight < 10_000_000, visibleHeight > 0 else { return }

        if abs(visibleHeight - lastVisibleHeight) >= 0.5 {
            lastVisibleHeight = visibleHeight
            scheduleViewportHeightUpdate(visibleHeight)
        }

        let distance = documentHeight - (offsetY + visibleHeight)
        // 迟滞：已在底部时用更宽容的离开阈值，不在底部时用更严格的进入阈值，
        // 避免在容差边界抖动时反复翻转。
        let tolerance = lastAtBottom
            ? MessageListScrollCoordinator.bottomLeaveTolerance
            : MessageListScrollCoordinator.bottomEnterTolerance
        let atBottom = distance <= tolerance

        guard atBottom != lastAtBottom else { return }
        lastAtBottom = atBottom
        onChange?(atBottom)
    }

    /// Defer the SwiftUI-facing callback until the current AppKit layout pass
    /// has returned. Without this hop, changing `viewportHeight` from inside
    /// `layout()` can re-enter List's AttributeGraph layout and hit SwiftUI's
    /// `DynamicLayoutViewChildGeometry` assertion.
    private func scheduleViewportHeightUpdate(_ height: CGFloat) {
        pendingViewportHeight = height
        guard viewportHeightUpdateTask == nil else { return }

        viewportHeightUpdateTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self else { return }
            self.viewportHeightUpdateTask = nil
            guard let pendingViewportHeight = self.pendingViewportHeight else { return }
            self.pendingViewportHeight = nil
            self.onViewportHeightChange?(pendingViewportHeight)
        }
    }

    /// 切换会话/重置滚动位置时由外部调用，把判定重置回「在底部」。
    /// （当前由 `atBottomBox.value = true` 直接重置，此处保留以备需要。）
    fileprivate func resetToBottom() {
        lastAtBottom = true
    }
}
