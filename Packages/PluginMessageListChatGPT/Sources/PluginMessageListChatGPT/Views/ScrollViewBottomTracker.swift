import AppKit
import SwiftUI

/// V5（ChatGPT）通过观察底层 `NSScrollView` 的滚动位置来判断
/// 「用户是否停在列表底部」，**完全替代** SwiftUI 的
/// `GeometryReader` + `PreferenceKey` 方案。
///
/// ## 为什么需要它
///
/// 旧方案在列表末尾挂一个 `GeometryReader { Color.clear.preference(...) }`，
/// 报告锚点的全局 maxY。在流式场景下（助手回复行高随 token 连续增长），这个锚点的
/// 全局坐标**每帧都在变**，导致列表永不收敛 → 主线程 100% CPU 活锁。
///
/// 本类型把「是否在底部」的判定从 SwiftUI 布局/偏好系统里**完全剥离**，
/// 改为由 AppKit 的 `NSClipView.boundsDidChangeNotification` 驱动
/// （仅在滚动时触发，流式行高度变化不会触发），彻底切断反馈环。
///
/// ## 线程与 invalidation
///
/// 观察者在主队列回调；闭包写入的内容（`AtBottomBox`）刻意不实现
/// `ObservableObject`，因此**不会**触发 SwiftUI invalidation ——
/// 这是切断反馈环的关键之一。
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
    ///
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

/// V5（ChatGPT）滚动观察器。
///
/// - Important: 本类型只做**观察与上报**，不做任何滚动决策。
///   滚动所有权由 `ChatGPTScrollAnchor` reducer 决定。
struct ScrollViewBottomTracker: NSViewRepresentable {
    /// 「是否在底部」布尔值翻转时回调。仅在真正翻转时调用，避免高频无意义触发。
    let onChange: (Bool) -> Void
    /// 提供给滚动协调器的底层滚动控制器，不参与 SwiftUI 布局。
    let controller: ScrollViewBottomController?
    /// Live-resize 结束时回调，参数为 resize **开始时**是否在底部。
    var onLiveResizeEnd: ((Bool) -> Void)?

    /// 滚动来源回调：来源 + 几何快照。
    var onScrollEvent: ((ChatGPTScrollEventSource, ScrollViewBottomController.Snapshot) -> Void)?

    /// 用户滚动的方向回调。
    ///
    /// - Important: 方向是用户意图的**直接**表达。
    ///   它比「离底多远」更早可用：用户往回滚的那一刻，
    ///   几何可能还停在底部（列表正在物化新行），但方向已经说明了意图。
    var onUserScrollDirection: ((ChatGPTUserScrollDirection) -> Void)?

    /// 是否应该继续自动跟随底部。
    ///
    /// - Important: V5 用它回答「文档变高后要不要重新钉底」。
    ///   用户已经上滚离开底部时（返回 false），文档随行物化变高
    ///   **不得**把用户拽回底部。
    var shouldAutoFollow: (() -> Bool)?

    init(
        onChange: @escaping (Bool) -> Void,
        controller: ScrollViewBottomController? = nil,
        onLiveResizeEnd: ((Bool) -> Void)? = nil,
        onScrollEvent: ((ChatGPTScrollEventSource, ScrollViewBottomController.Snapshot) -> Void)? = nil,
        shouldAutoFollow: (() -> Bool)? = nil,
        onUserScrollDirection: ((ChatGPTUserScrollDirection) -> Void)? = nil
    ) {
        self.onChange = onChange
        self.controller = controller
        self.onLiveResizeEnd = onLiveResizeEnd
        self.onScrollEvent = onScrollEvent
        self.shouldAutoFollow = shouldAutoFollow
        self.onUserScrollDirection = onUserScrollDirection
    }

    func makeNSView(context: Context) -> TrackerView {
        let view = TrackerView()
        // Important: 必须在 `makeNSView` 里就设好回调。
        //   `attach`（进而 `startUserEventMonitor`）可能在视图挂到窗口时
        //   就发生，那时 `updateNSView` 还没跑，回调仍是 nil ——
        //   用户输入监测因此根本没装上，真实用户滚动永远改变不了 following。
        view.bottomController = controller
        view.onChange = { [weak coordinator = context.coordinator] atBottom in
            coordinator?.onChange(atBottom)
        }
        view.onLiveResizeEnd = { [weak coordinator = context.coordinator] wasAtBottom in
            coordinator?.onLiveResizeEnd?(wasAtBottom)
        }
        view.onScrollEvent = { [weak coordinator = context.coordinator] source, snapshot in
            coordinator?.onScrollEvent?(source, snapshot)
        }
        view.shouldAutoFollow = shouldAutoFollow
        view.onUserScrollDirection = { [weak coordinator = context.coordinator] direction in
            coordinator?.onUserScrollDirection?(direction)
        }
        return view
    }

    func updateNSView(_ nsView: TrackerView, context: Context) {
        // 故意不做任何尺寸/几何相关工作 —— 这里一旦触碰布局就会重新进入
        // SwiftUI 的尺寸协商，可能复活反馈环。仅同步回调句柄。
        context.coordinator.onChange = onChange
        context.coordinator.onLiveResizeEnd = onLiveResizeEnd
        context.coordinator.onScrollEvent = onScrollEvent
        context.coordinator.onUserScrollDirection = onUserScrollDirection
        nsView.bottomController = controller
        nsView.onScrollEvent = onScrollEvent
        nsView.shouldAutoFollow = shouldAutoFollow
        nsView.onUserScrollDirection = onUserScrollDirection
    }

    static func dismantleNSView(_ nsView: TrackerView, coordinator: Coordinator) {
        nsView.stopObserving()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onChange: onChange,
            onLiveResizeEnd: onLiveResizeEnd,
            onScrollEvent: onScrollEvent,
            onUserScrollDirection: onUserScrollDirection
        )
    }

    final class Coordinator {
        var onChange: (Bool) -> Void
        var onLiveResizeEnd: ((Bool) -> Void)?
        var onScrollEvent: ((ChatGPTScrollEventSource, ScrollViewBottomController.Snapshot) -> Void)?
        var onUserScrollDirection: ((ChatGPTUserScrollDirection) -> Void)?

        init(
            onChange: @escaping (Bool) -> Void,
            onLiveResizeEnd: ((Bool) -> Void)?,
            onScrollEvent: ((ChatGPTScrollEventSource, ScrollViewBottomController.Snapshot) -> Void)? = nil,
            onUserScrollDirection: ((ChatGPTUserScrollDirection) -> Void)? = nil
        ) {
            self.onChange = onChange
            self.onLiveResizeEnd = onLiveResizeEnd
            self.onScrollEvent = onScrollEvent
            self.onUserScrollDirection = onUserScrollDirection
        }
    }
}

/// 承载观察逻辑的 NSView。零尺寸、不绘制、不参与布局尺寸协商。
@MainActor
final class TrackerView: NSView {
    fileprivate var onChange: ((Bool) -> Void)?
    fileprivate var onLiveResizeEnd: ((Bool) -> Void)?
    fileprivate var bottomController: ScrollViewBottomController?
    /// 滚动来源回调。
    fileprivate var onScrollEvent: ((ChatGPTScrollEventSource, ScrollViewBottomController.Snapshot) -> Void)?
    /// 是否应该继续自动跟随底部。
    fileprivate var shouldAutoFollow: (() -> Bool)?
    /// 用户滚动方向回调。
    fileprivate var onUserScrollDirection: ((ChatGPTUserScrollDirection) -> Void)?
    /// 待上报的用户滚动方向。
    private var pendingUserScrollDirection: ChatGPTUserScrollDirection?
    /// 程序化滚动作用域：贴底写入 clip bounds 期间置位。
    private var programmaticScope = ChatGPTProgrammaticScrollScope()
    /// 用户输入监测器。
    private var userEventMonitor: Any?
    /// 观察到的滚动视图所属 window 的标识；用于过滤其它 window 的事件。
    private var targetWindowIdentifier: ObjectIdentifier?
    private var observation: NSObjectProtocol?
    /// 文档视图尺寸变化的观察者。
    ///
    /// - Important: 这一路观察是「自动滚动没彻底到底」的根因所在。
    ///   `List` 的行高是**事后修正**的：懒加载行陆续物化、Markdown 异步
    ///   解析后回填正文，都会让 `documentView` 在**滚到底的收敛循环已经
    ///   退出之后**继续变高。而这类增长**不会**触发 clip view 的
    ///   `boundsDidChangeNotification`。
    private var documentObservation: NSObjectProtocol?
    private weak var observedScrollView: NSScrollView?
    /// 文档视图尺寸变化的通知对象。SwiftUI `List` 复用同一个 document
    /// view，但换会话重建 `List` 时可能换新，需要重新挂观察者。
    private weak var observedDocumentView: NSView?
    /// 上一次已知的文档高度。
    private var lastObservedDocumentHeight: CGFloat = -1
    /// 上一次已知的「文档最大滚动偏移」（= documentHeight - visibleHeight）。
    ///
    /// 用来回答「文档变高**之前**我们是否停在底部」。必须用增长**前**的值比较：
    /// 用户可能在上一次同步之后就已经上滚了。
    private var lastKnownMaxOffsetY: CGFloat = 0
    /// 钉底过程中置位，防止「写 clip bounds → 触发观察 → 再钉」的回环。
    private var isPinningToBottom = false
    /// 上一次报告的「是否在底部」，用于迟滞判定、避免无谓回调。
    private var lastAtBottom: Bool = true
    /// 纯几何判定器（无 AppKit 依赖，可单测）。
    private let evaluator = BottomEdgeEvaluator()

    // MARK: - Live-resize 恢复

    /// resize 开始时记录的 contentOffset（仅非底部场景用于松手后恢复阅读位置）。
    private var savedOriginY: CGFloat?
    /// resize 开始时是否在底部。
    private var resizeStartedAtBottom: Bool = false
    /// 底部场景：resize 结束后是否正在执行「持续钉底」恢复。
    private var isRestoringAfterResize = false
    /// 非底部场景：松手后多帧恢复计数。
    private var restoreAttempts = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: .zero)
        // 不绘制、不参与命中测试，纯粹作为「挂在视图树里用来找 scrollView」的锚点。
        wantsLayer = false
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
        // Tracker 作为 SwiftUI background 安装，可能在进入视图层级后才被布局。
        // 在这里重试，直到找到自己的祖先滚动视图。
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
        // Tracker 必须绑定到自己的消息 List。禁止从 window.contentView
        // 全局扫描，否则同一个窗口里的侧栏 NSScrollView 可能被误选中。
        guard let scrollView = findOwningScrollView() else {
            stopObserving()
            return
        }
        guard scrollView !== observedScrollView else { return }

        attach(to: scrollView)
    }

    /// 找到承载本 tracker 的滚动视图。
    ///
    /// - Important: **不能**只用 AppKit 的 `enclosingScrollView`。
    ///   它只在视图是滚动视图的**后代**时才返回值；而 tracker 是挂在
    ///   `List` 上的 `background`，在 macOS 上它是滚动视图的**兄弟**，
    ///   `enclosingScrollView` 恒为 nil —— 观察者因此从未挂上，
    ///   「是否在底部」永远不更新。
    ///
    ///   这里改为**向上遍历父视图链**，找第一个 `NSScrollView`；
    ///   找不到再退回 `enclosingScrollView`。
    private func findOwningScrollView() -> NSScrollView? {
        var candidate: NSView? = self
        while let view = candidate {
            if let scrollView = view as? NSScrollView {
                return scrollView
            }
            candidate = view.superview
        }
        if let enclosing = enclosingScrollView { return enclosing }

        // 兜底：从 window 层级里找**最窄的、且包含本 tracker 横向范围**的滚动视图。
        guard let window else { return nil }
        var candidates: [NSScrollView] = []
        func collect(_ view: NSView) {
            if let scrollView = view as? NSScrollView { candidates.append(scrollView) }
            for sub in view.subviews { collect(sub) }
        }
        collect(window.contentView ?? NSView())
        // 消息列表是窗口里最宽的滚动视图（会话列表只有 240）。
        return candidates
            .filter { $0.frame.width >= 400 }
            .max { $0.frame.width < $1.frame.width }
    }

    /// 绑定滚动视图并挂上观察者。
    private func attach(to scrollView: NSScrollView) {
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
        // 观察文档视图的尺寸变化 —— 这是「自动滚动没彻底到底」的关键。
        startObservingDocumentView(of: scrollView)
        // 启动用户输入监测，用于区分真实用户滚动与程序化/布局滚动。
        startUserEventMonitor(for: scrollView)
        // 附着后立刻评估一次，把初始状态同步给回调。
        reevaluate()
    }

    /// 挂上文档视图的尺寸观察者。
    ///
    /// - Important: `frameDidChangeNotification` 在 AppKit 的布局过程中发出，
    ///   此时**不能**同步写 `clipView.bounds`（会与 AppKit 正在进行的布局
    ///   打架）。因此只在这里记录「文档变高了」，把真正的钉底动作推迟到
    ///   下一个主线程回合。
    private func startObservingDocumentView(of scrollView: NSScrollView) {
        guard let documentView = scrollView.documentView else { return }
        stopObservingDocumentView()
        observedDocumentView = documentView
        lastObservedDocumentHeight = documentView.bounds.height
        lastKnownMaxOffsetY = currentMaxOffsetY()
        documentObservation = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: documentView,
            queue: .main
        ) { [weak self] _ in
            // 回调用 `queue: .main` 投递，**已经**在布局之后的下一个主线程回合执行，
            // 因此这里可以直接钉底。不要再套一层 `Task { @MainActor }`：
            // 主 actor 被占满时那类推迟会被无限期延后。
            MainActor.assumeIsolated {
                self?.handleDocumentFrameChange()
            }
        }
    }

    private func stopObservingDocumentView() {
        if let documentObservation {
            NotificationCenter.default.removeObserver(documentObservation)
            self.documentObservation = nil
        }
        observedDocumentView = nil
        lastObservedDocumentHeight = -1
    }

    /// 文档高度变化时的处理：**在用户仍处于底部的前提下**重新钉住底沿。
    ///
    /// - Important: 用户已经上滚离开底部时**不得**重新钉底。
    ///   文档随行物化变高（用户往回看时正好会物化更多行）
    ///   若继续钉底，用户会被硬拽回底部 —— 那正是 V5 要修的核心问题。
    private func handleDocumentFrameChange() {
        guard !isPinningToBottom else { return }
        guard !isRestoringAfterResize else { return }
        if let shouldAutoFollow, !shouldAutoFollow() {
            lastObservedDocumentHeight = observedDocumentView?.bounds.height ?? -1
            lastKnownMaxOffsetY = currentMaxOffsetY()
            return
        }
        guard let scrollView = observedScrollView,
              let documentView = scrollView.documentView else { return }

        let newHeight = documentView.bounds.height
        let previousHeight = lastObservedDocumentHeight
        guard previousHeight >= 0 else {
            lastObservedDocumentHeight = newHeight
            lastKnownMaxOffsetY = currentMaxOffsetY()
            return
        }
        guard abs(newHeight - previousHeight) > 0.5 else { return }

        // 文档变矮（行被回收 / 内容替换）不做处理：向下钉底没有意义，
        // 而且会把用户正在读的位置弄丢。
        guard newHeight > previousHeight else {
            lastObservedDocumentHeight = newHeight
            lastKnownMaxOffsetY = currentMaxOffsetY()
            return
        }

        // 文档变高**之前**我们是否停在底部？用增长前的 maxOffset 比较。
        let wasAtBottomBeforeGrowth = lastKnownMaxOffsetY - currentOffsetY()
            <= MessageListScrollCoordinator.bottomLeaveTolerance

        lastObservedDocumentHeight = newHeight
        lastKnownMaxOffsetY = currentMaxOffsetY()

        guard wasAtBottomBeforeGrowth else { return }

        // 推迟到下一个主线程回合：此刻正处于 AppKit 布局过程中，
        // 同步写 clipView.bounds 会与布局打架。
        DispatchQueue.main.async { [weak self] in
            self?.pinBottomAfterDocumentGrowth()
        }
    }

    /// 文档变高后重新钉底。
    ///
    /// 钉底之后**必须**再做一次底部判定：此时 `distance` 归零，
    /// `atBottomBox` 保持 true —— 否则 `lastAtBottom` 停留在 false，
    /// 后续新消息不再跟随滚动。
    private func pinBottomAfterDocumentGrowth() {
        guard !isPinningToBottom else { return }
        guard let scrollView = observedScrollView,
              let documentView = scrollView.documentView else { return }

        isPinningToBottom = true
        defer { isPinningToBottom = false }

        let clipView = scrollView.contentView
        let documentHeight = documentView.bounds.height
        let visibleHeight = clipView.bounds.height
        let maxOffsetY = max(0, documentHeight - visibleHeight)
        let currentY = clipView.bounds.origin.y

        // 已经在新的底沿上，无需再动。
        guard abs(maxOffsetY - currentY) > 0.5 else {
            lastKnownMaxOffsetY = maxOffsetY
            reevaluate()
            return
        }

        var bounds = clipView.bounds
        bounds.origin.y = maxOffsetY
        clipView.bounds = bounds
        scrollView.reflectScrolledClipView(clipView)

        lastKnownMaxOffsetY = maxOffsetY
        // 钉底之后重新判定：distance 现在是 0，`lastAtBottom` 应为 true。
        reevaluate()
    }

    private func currentOffsetY() -> CGFloat {
        observedScrollView?.contentView.bounds.origin.y ?? 0
    }

    private func currentMaxOffsetY() -> CGFloat {
        guard let scrollView = observedScrollView,
              let documentView = scrollView.documentView else { return 0 }
        let documentHeight = documentView.bounds.height
        let visibleHeight = scrollView.contentView.bounds.height
        return max(0, documentHeight - visibleHeight)
    }

    /// 更换底部几何控制器。
    ///
    /// - Important: 控制器换了实例时**必须**把它重新绑定到当前观察的滚动视图。
    internal func setBottomController(_ controller: ScrollViewBottomController?) {
        guard bottomController !== controller else { return }
        if let observedScrollView {
            bottomController?.detach(from: observedScrollView)
            controller?.attach(to: observedScrollView)
        }
        bottomController = controller
    }

    /// 挂上 clip view 的偏移观察**和** document view 的尺寸观察。
    /// 单测无法构造 SwiftUI 视图层级，故提供此缝直接注入。
    internal func attachForTesting(to scrollView: NSScrollView) {
        attach(to: scrollView)
    }

    /// 供单测解绑，用于验证解绑后不再重新钉底。
    internal func detachForTesting() {
        stopObserving()
    }

    /// 供单测读取「上一次报告的底部状态」。
    internal var lastReportedAtBottomForTesting: Bool { lastAtBottom }

    /// 供单测捕获底部状态回调序列。
    internal var onChangeForTesting: ((Bool) -> Void)? {
        get { onChange }
        set { onChange = newValue }
    }

    fileprivate func stopObserving() {
        if let observation {
            NotificationCenter.default.removeObserver(observation)
            self.observation = nil
        }
        stopObservingDocumentView()
        stopUserEventMonitor()
        if let observedScrollView {
            bottomController?.detach(from: observedScrollView)
        }
        observedScrollView = nil
        programmaticScope = ChatGPTProgrammaticScrollScope()
    }

    // MARK: - 底部判定（迟滞带）

    /// 重新判定「是否在底部」并在翻转时回调。
    private func reevaluate() {
        guard !isRestoringAfterResize else { return }
        guard let scrollView = observedScrollView,
              let documentView = scrollView.documentView else { return }

        let clipView = scrollView.contentView
        guard let result = evaluator.evaluate(
            documentHeight: documentView.bounds.height,
            visibleHeight: clipView.bounds.height,
            offsetY: clipView.bounds.origin.y,
            previousAtBottom: lastAtBottom
        ) else { return }

        lastAtBottom = result.atBottom
        if result.shouldNotify {
            onChange?(result.atBottom)
        }
    }

    // MARK: - 滚动来源

    /// 上报一次滚动来源事件。
    ///
    /// - Important: 这里**不能**按「来源去重」。
    ///   去重会让**只有第一次**用户滚动被上报，
    ///   之后的上滚永远改变不了 `following` ——
    ///   「回到底部」按钮因此永远不出现。
    private func reportScrollEvent(
        _ source: ChatGPTScrollEventSource,
        direction: ChatGPTUserScrollDirection? = nil
    ) {
        guard let onScrollEvent else { return }
        pendingUserScrollDirection = direction
        guard let snapshot = currentSnapshot() else { return }
        let direction = pendingUserScrollDirection
        pendingUserScrollDirection = nil
        onScrollEvent(source, snapshot)
    }

    /// 从事件推导用户滚动方向。
    ///
    /// - Note: AppKit 的 `scrollingDeltaY` 语义：
    ///   **负值**表示内容**向上**移动（用户把内容往上推），
    ///   视口于是往下走、看到**更晚**的内容 —— 那是「往前」。
    ///
    ///   - Important: 写反的症状是「用户往上滚了，`following` 反而恢复」，
    ///     于是「回到底部」按钮永远不出现。
    private func userScrollDirection(
        from input: ChatGPTScrollSourceInput
    ) -> ChatGPTUserScrollDirection? {
        switch input.kind {
        case .scrollWheel, .touch:
            guard input.deltaY != 0 else { return nil }
            return input.deltaY < 0 ? .forward : .backward
        case .key:
            switch input.key {
            case "ArrowUp", "PageUp", "Home":
                return .backward
            case "ArrowDown", "PageDown", "End":
                return .forward
            default:
                return nil
            }
        case .scrollbar:
            // 滚动条拖动无法从事件里拿到方向，交由几何判定。
            return nil
        default:
            return nil
        }
    }

    /// 推迟一个主线程回合后上报用户滚动。
    private func scheduleUserScrollReport(direction: ChatGPTUserScrollDirection?) {
        Task { @MainActor [weak self] in
            // 让 AppKit 完成本轮滚动的布局与偏移更新。
            await Task.yield()
            guard let self else { return }
            self.reportScrollEvent(.user, direction: direction)
        }
    }

    /// 当前几何快照。
    private func currentSnapshot() -> ScrollViewBottomController.Snapshot? {
        guard let scrollView = observedScrollView,
              let documentView = scrollView.documentView else { return nil }
        let clipView = scrollView.contentView
        return ScrollViewBottomController.Snapshot(
            documentHeight: documentView.bounds.height,
            visibleHeight: clipView.bounds.height,
            offsetY: clipView.bounds.origin.y
        )
    }

    /// 启动用户输入监测。
    ///
    /// - Important: 监测必须按 **window + 滚动视图**过滤，
    ///   否则侧栏的滚动会被误当成消息列表的滚动。
    private func startUserEventMonitor(for scrollView: NSScrollView) {
        stopUserEventMonitor()

        targetWindowIdentifier = scrollView.window.map { ObjectIdentifier($0) }

        let monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.scrollWheel, .keyDown]
        ) { [weak self] event in
            guard let self else { return event }

            // 过滤：必须是同一个 window。
            if let targetID = self.targetWindowIdentifier,
               let eventWindowID = event.window.map({ ObjectIdentifier($0) }),
               eventWindowID != targetID {
                return event
            }

            // 过滤：事件必须落在当前观察的滚动视图上。
            guard let observed = self.observedScrollView else { return event }
            guard self.eventTargetsScrollView(event, scrollView: observed) else { return event }

            let input: ChatGPTScrollSourceInput
            switch event.type {
            case .scrollWheel:
                input = ChatGPTScrollSourceInput(
                    kind: .scrollWheel,
                    deltaY: event.scrollingDeltaY,
                    isEditableTarget: self.isEditableTarget(event),
                    isProgrammaticScopeActive: self.programmaticScope.isActive
                )
            case .keyDown:
                input = ChatGPTScrollSourceInput(
                    kind: .key,
                    key: Self.keyName(event),
                    isEditableTarget: self.isEditableTarget(event),
                    isProgrammaticScopeActive: self.programmaticScope.isActive
                )
            default:
                return event
            }

            let source = ChatGPTScrollSourceClassifier.classify(input)
            if source == .user {
                // 方向先报：它是用户意图的直接表达，不受几何时序影响。
                let direction = userScrollDirection(from: input)
                if let direction {
                    MainActor.assumeIsolated {
                        self.onUserScrollDirection?(direction)
                    }
                }
                // Important: 几何快照必须**等滚动真正发生之后**再取。
                //   事件派发的瞬间 clip view 的偏移量还是**滚动前**的值，
                //   用它判定「是否在底部」永远得到「在底部」，
                //   `following` 于是永远不会解除。
                MainActor.assumeIsolated {
                    self.scheduleUserScrollReport(direction: direction)
                }
            }
            return event
        }
        userEventMonitor = monitor
    }

    /// 停止用户输入监测。
    private func stopUserEventMonitor() {
        if let userEventMonitor {
            NSEvent.removeMonitor(userEventMonitor)
            self.userEventMonitor = nil
        }
    }

    /// 事件是否发生在给定滚动视图上。
    ///
    /// - Important: 用事件的**坐标**判定，而不是 `firstResponder`。
    ///   合成事件（`CGEvent.post`）的 `firstResponder` 通常是窗口本身，
    ///   不是滚动视图；按 firstResponder 过滤会把所有用户滚动都丢掉。
    ///
    ///   坐标判定同时排除了侧栏的滚动：它不在消息列表的矩形里。
    private func eventTargetsScrollView(_ event: NSEvent, scrollView: NSScrollView) -> Bool {
        guard let eventWindow = event.window,
              let scrollWindow = scrollView.window,
              eventWindow === scrollWindow
        else { return false }

        // `convert(_:to: nil)` 把视图坐标换成**窗口坐标**，
        // 与 `event.locationInWindow` 同一坐标系。
        let scrollFrame = scrollView.convert(scrollView.bounds, to: nil)
        return scrollFrame.contains(event.locationInWindow)
    }

    /// 事件目标是否落在可编辑控件里。
    private func isEditableTarget(_ event: NSEvent) -> Bool {
        guard let target = event.window?.firstResponder as? NSView else { return false }
        if target is NSTextView { return true }
        if target is NSTextField { return true }
        if let field = target as? NSTextField { return field.isEditable }
        if let control = target as? NSControl, control.isEnabled { return false }
        return false
    }

    /// 按键名。
    private static func keyName(_ event: NSEvent) -> String {
        guard let characters = event.charactersIgnoringModifiers else { return "" }
        switch characters {
        case "\u{1B}": return "Escape"
        case "\r", "\n": return "Enter"
        case "\t": return "Tab"
        case " ": return " "
        default: return characters
        }
    }

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
            isRestoringAfterResize = true
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
                // NSScrollView 同步内部状态（滚动条/缓存），
                // 否则写入可能被下一次 layout 覆盖回去。
                var newBounds = clipView.bounds
                newBounds.origin.y = maxOffset
                clipView.bounds = newBounds
                scrollView.reflectScrolledClipView(clipView)

                // 几何稳定 = documentView 高度不再变 且 钉底后的 offset 也不再变。
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
    /// 确保后续流式跟随滚动正常工作。
    private func finishBottomRestore() {
        isRestoringAfterResize = false
        savedOriginY = nil
        // 主动把状态翻回 true 并通知宿主 —— 即使恢复过程中曾被 suppress
        // 偏离过底部，落地后语义上用户仍应被视为「在底部」。
        if !lastAtBottom {
            lastAtBottom = true
            onChange?(true)
        }
        reevaluate()
    }

    /// 非底部场景：松手后多帧恢复 contentOffset。
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
        guard let scrollView = observedScrollView ?? enclosingScrollView,
              let documentView = scrollView.documentView else { return }
        guard let originY = savedOriginY else { return }

        let clipView = scrollView.contentView
        let documentHeight = documentView.bounds.height
        let visibleHeight = clipView.bounds.height
        let maxOffset = max(0, documentHeight - visibleHeight)
        // 恢复位置被文档裁剪到有效范围内。
        let restored = min(max(0, originY), maxOffset)

        var bounds = clipView.bounds
        bounds.origin.y = restored
        clipView.bounds = bounds
        scrollView.reflectScrolledClipView(clipView)

        if abs(restored - originY) < 0.5 {
            savedOriginY = nil
            reevaluate()
            return
        }
        scheduleRestore()
    }
}
