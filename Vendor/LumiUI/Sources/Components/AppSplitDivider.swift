import OSLog
import SwiftUI

#if os(macOS)
import AppKit
#endif

/// The edge of the pane that owns a split-view divider.
///
/// Apply ``View/appSplitDivider(_:)`` to the pane adjacent to the divider:
/// use `.trailing`/`.bottom` on the pane before it, or `.leading` on the pane
/// after it when the decoration should be rendered on the trailing side.
public enum AppSplitDividerEdge: Sendable {
    /// A divider immediately before the pane receiving the modifier.
    case leading
    case trailing
    case bottom

    fileprivate var alignment: Alignment {
        switch self {
        case .leading: .leading
        case .trailing: .trailing
        case .bottom: .bottom
        }
    }

    fileprivate var expectsVerticalSplit: Bool {
        switch self {
        case .leading, .trailing: true
        case .bottom: false
        }
    }
}

/// Which pane's native size should be reported after a divider drag.
public enum AppSplitDividerResizeTarget: Sendable {
    case leading
    case trailing
}

public extension View {
    /// Adds Lumi's interactive styling to a horizontal split divider.
    ///
    /// `.trailing` styles the divider after the modified pane, while `.leading`
    /// styles the divider before it. The divider gets a subtle inset shadow,
    /// becomes more prominent on hover, and uses the matching resize cursor
    /// without intercepting native dragging.
    /// Hover feedback is limited to the native draggable area so the cursor never
    /// advertises resizing where `NSSplitView` cannot begin a drag.
    func appSplitDivider(_ edge: AppSplitDividerEdge) -> some View {
        appSplitDivider(edge, initialPosition: nil, onResize: nil)
    }

    /// Adds interactive styling, restores the divider once after attachment, and
    /// reports a pane's native size after resize. `initialTrailingSize` is useful
    /// when the desired size belongs to the pane after a horizontal divider,
    /// such as a bottom Content Footer.
    ///
    /// Pass `restingShadow: false` for dividers whose resting shadow is
    /// undesirable — for example a rail sitting next to a panel bar that already
    /// draws its own edge. Hover still reveals the shadow, so the divider stays
    /// discoverable.
    func appSplitDivider(
        _ edge: AppSplitDividerEdge,
        initialPosition: CGFloat? = nil,
        initialTrailingSize: CGFloat? = nil,
        restingShadow: Bool = true,
        resizeTarget: AppSplitDividerResizeTarget = .leading,
        onResize: (@MainActor (CGFloat) -> Void)?
    ) -> some View {
        modifier(
            AppSplitDividerModifier(
                edge: edge,
                initialPosition: initialPosition,
                initialTrailingSize: initialTrailingSize,
                restingShadow: restingShadow,
                resizeTarget: resizeTarget,
                onResize: onResize
            )
        )
    }
}

private struct AppSplitDividerModifier: ViewModifier {
    @LumiTheme private var theme
    @State private var isHovered = false

    let edge: AppSplitDividerEdge
    let initialPosition: CGFloat?
    let initialTrailingSize: CGFloat?
    let restingShadow: Bool
    let resizeTarget: AppSplitDividerResizeTarget
    let onResize: (@MainActor (CGFloat) -> Void)?

    func body(content: Content) -> some View {
        content
            .background(
                dividerHoverCoordinator
            )
            .overlay(alignment: edge.alignment) {
                dividerDecoration
            }
    }

    /// 悬停状态的来源。
    ///
    /// - macOS：挂载 `NSSplitView` 协调器，在原生分隔条命中区域上跟踪悬停，
    ///   并接管分隔条的初始位置恢复与拖拽后尺寸上报。
    /// - iOS / visionOS：没有 `NSSplitView`，改用 SwiftUI 的 `onHover`，
    ///   仅保留分隔线的视觉表现（悬停加粗 + 阴影显现）。
    @ViewBuilder
    private var dividerHoverCoordinator: some View {
        #if os(macOS)
        AppSplitDividerHoverCoordinator(
            edge: edge,
            isHovered: $isHovered,
            initialPosition: initialPosition,
            initialTrailingSize: initialTrailingSize,
            resizeTarget: resizeTarget,
            onResize: onResize
        )
        #else
        Color.clear
            .onHover { hovering in
                isHovered = hovering
            }
        #endif
    }

    @ViewBuilder
    private var dividerDecoration: some View {
        switch edge {
        case .leading:
            ZStack(alignment: .leading) {
                LinearGradient(
                    colors: [.black.opacity(shadowOpacity), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .allowsHitTesting(false)

                Rectangle()
                    .fill(theme.divider)
                    .frame(width: isHovered ? 0.6 : 0.5)
                    .allowsHitTesting(false)
            }
            .frame(width: 8)

        case .trailing:
            ZStack(alignment: .trailing) {
                LinearGradient(
                    colors: [.clear, .black.opacity(shadowOpacity)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .allowsHitTesting(false)

                Rectangle()
                    .fill(theme.divider)
                    .frame(width: isHovered ? 0.6 : 0.5)
                    .allowsHitTesting(false)
            }
            .frame(width: 8)

        case .bottom:
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [.clear, .black.opacity(shadowOpacity)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                Rectangle()
                    .fill(theme.divider)
                    .frame(height: isHovered ? 0.6 : 0.5)
                    .allowsHitTesting(false)
            }
            .frame(height: 8)
        }
    }

    /// 阴影不透明度：hover 时显现；静息态在 `restingShadow` 为 `false` 时完全隐藏，
    /// 但分隔线本身（`theme.divider`）与 hover 反馈始终保留。
    private var shadowOpacity: Double {
        AppSplitDividerShadow.opacity(isHovered: isHovered, restingShadow: restingShadow)
    }
}

/// 分隔线渐变阴影的不透明度。抽成独立类型以便直接验证 hover / 静息两种状态的取值，
/// 无需构造视图。
enum AppSplitDividerShadow {
    /// 静息态阴影（未显式关闭时）。
    static let resting: Double = 0.04
    /// hover 态阴影。
    static let hovered: Double = 0.1

    static func opacity(isHovered: Bool, restingShadow: Bool) -> Double {
        guard isHovered else { return restingShadow ? resting : 0 }
        return hovered
    }
}

#if os(macOS)
private struct AppSplitDividerHoverCoordinator: NSViewRepresentable {
    let edge: AppSplitDividerEdge
    @Binding var isHovered: Bool
    let initialPosition: CGFloat?
    let initialTrailingSize: CGFloat?
    let resizeTarget: AppSplitDividerResizeTarget
    let onResize: (@MainActor (CGFloat) -> Void)?

    func makeNSView(context: Context) -> AppSplitDividerHoverCoordinatorView {
        let view = AppSplitDividerHoverCoordinatorView(
            edge: edge,
            initialPosition: initialPosition,
            initialTrailingSize: initialTrailingSize,
            resizeTarget: resizeTarget,
            onResize: onResize
        )
        view.onHoverChanged = { hovering in
            isHovered = hovering
        }
        return view
    }

    func updateNSView(_ nsView: AppSplitDividerHoverCoordinatorView, context: Context) {
        nsView.edge = edge
        nsView.initialPosition = initialPosition
        nsView.initialTrailingSize = initialTrailingSize
        nsView.resizeTarget = resizeTarget
        nsView.onResize = onResize
        nsView.onHoverChanged = { hovering in
            isHovered = hovering
        }
        // 只在尚未 attach 成功时才探测。已 attach 的 SwiftUI 更新不重跑坐标搜索,
        // 避免流式/滚动等高频更新反复触发 `enclosingSplitView` + `dividerIndex`。
        if nsView.splitView == nil {
            nsView.attachToSplitViewIfPossible()
        } else {
            nsView.applyInitialPositionIfNeeded()
        }
    }

    static func dismantleNSView(_ nsView: AppSplitDividerHoverCoordinatorView, coordinator: ()) {
        // 拆除期间先摘除回调:detach() 里的 onHoverChanged?(false) 会向宿主的
        // @Binding isHovered 写回,而此时 SwiftUI 正在销毁该 State 存储
        // (StoredLocation.isUpdating),写回会触发独占性访问检查 fatalError
        // (每次退出必崩,SIGABRT)。悬停状态随视图销毁本就无意义。
        nsView.onHoverChanged = nil
        nsView.detach()
    }
}

@MainActor
private final class AppSplitDividerHoverCoordinatorView: NSView {
    private static let verbose = false
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "split-divider")

    var edge: AppSplitDividerEdge
    var initialPosition: CGFloat?
    var initialTrailingSize: CGFloat?
    var resizeTarget: AppSplitDividerResizeTarget
    var onHoverChanged: ((Bool) -> Void)?
    var onResize: (@MainActor (CGFloat) -> Void)?

    fileprivate weak var splitView: NSSplitView?
    private var dividerIndex: Int?
    private var trackingArea: NSTrackingArea?
    private var resizeObserver: NSObjectProtocol?
    private var resizeCompletionWorkItem: DispatchWorkItem?
    private var isResizeGestureActive = false
    private var hasPendingResize = false
    private var isOverNativeDivider = false
    private var measuredTrackingThickness: CGFloat?
    private var appliedInitialPosition: CGFloat?

    /// 已尝试 attach 的次数。未挂到 NSSplitView 时用指数退避重试,超过上限放弃,
    /// 避免在「视图根本不在 split view 里」时形成每帧 `DispatchQueue.main.async`
    /// 重调自己的主线程忙循环(实测会把主线程打满数秒,UI 完全卡住)。
    private var attachAttemptCount: Int = 0
    private var isScheduledForRetry = false

    init(
        edge: AppSplitDividerEdge,
        initialPosition: CGFloat? = nil,
        initialTrailingSize: CGFloat? = nil,
        resizeTarget: AppSplitDividerResizeTarget = .leading,
        onResize: (@MainActor (CGFloat) -> Void)? = nil
    ) {
        self.edge = edge
        self.initialPosition = initialPosition
        self.initialTrailingSize = initialTrailingSize
        self.resizeTarget = resizeTarget
        self.onResize = onResize
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            // 新挂到 window:重置重试计数,允许重新探测。
            attachAttemptCount = 0
            isScheduledForRetry = false
            attachToSplitViewIfPossible()
        } else {
            // 视图离开窗口是拆除前奏:同样先摘除回调再取消重试,避免后续
            // detach() 的 onHoverChanged?(false) 在 State 销毁期间写回 @Binding。
            onHoverChanged = nil
            cancelRetry()
        }
    }

    func attachToSplitViewIfPossible() {
        // 已成功 attach 且未变化时,`updateNSView` 的反复调用会直接命中这里 return,
        /// 不会每帧重跑坐标搜索。
        guard window != nil else {
            cancelRetry()
            return
        }
        guard let resolvedSplitView = enclosingSplitView(),
              let resolvedDividerIndex = dividerIndex(in: resolvedSplitView)
        else {
            // 还没挂到 split view(布局未完成,或本就不在 split view 里)。
            // 指数退避重试,超过上限后放弃 —— 不再 `async` 重调自己。
            scheduleRetryIfNeeded()
            return
        }

        guard splitView !== resolvedSplitView || dividerIndex != resolvedDividerIndex else {
            return
        }

        // 成功定位:清掉重试状态。
        attachAttemptCount = 0
        isScheduledForRetry = false

        detach()
        splitView = resolvedSplitView
        dividerIndex = resolvedDividerIndex
        if Self.verbose {
            Self.logger.info(
                "attach orientation=\(resolvedSplitView.isVertical ? "vertical-line" : "horizontal-line", privacy: .public) index=\(resolvedDividerIndex) bounds=\(String(describing: resolvedSplitView.bounds), privacy: .public)"
            )
        }
        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSSplitView.didResizeSubviewsNotification,
            object: resolvedSplitView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                if Self.verbose {
                    Self.logger.info("didResizeSubviews pending resize")
                }
                // NSSplitView posts this notification continuously while dragging.
                // Keep this path constant-time; rebuilding the tracking area here
                // causes visible frame drops on every mouse movement.
                guard NSEvent.pressedMouseButtons & 1 != 0 else { return }
                self?.isResizeGestureActive = true
                self?.hasPendingResize = true
                self?.scheduleResizeCompletionCheck()
            }
        }
        refreshTrackingArea()
        hideNativeDivider()
        DispatchQueue.main.async { [weak self] in
            self?.applyInitialPositionIfNeeded()
        }
    }

    func detach() {
        cancelRetry()
        onHoverChanged?(false)
        isOverNativeDivider = false
        if let trackingArea, let splitView {
            splitView.removeTrackingArea(trackingArea)
        }
        trackingArea = nil
        if let resizeObserver {
            NotificationCenter.default.removeObserver(resizeObserver)
        }
        resizeObserver = nil
        resizeCompletionWorkItem?.cancel()
        resizeCompletionWorkItem = nil
        isResizeGestureActive = false
        hasPendingResize = false
        dividerIndex = nil
        splitView = nil
        measuredTrackingThickness = nil
        appliedInitialPosition = nil
    }

    // MARK: - Retry (指数退避,有上限)

    /// 探测失败(尚未挂到 split view)时调度一次退避重试。
    ///
    /// 旧实现无条件 `DispatchQueue.main.async { self?.attach... }`,在视图根本
    /// 不在 NSSplitView 里(或布局未完成)时会形成**每帧重调自己的主线程忙循环**,
    /// 把主线程 runloop 填满、UI 卡死数秒。这里改为:
    /// - 最多重试 8 次;
    /// - 退避间隔从 4ms 指数增长到约 1s(2^(n-1) ms 量级),越往后越稀疏;
    /// - 同一时间只挂一个重试。
    private func scheduleRetryIfNeeded() {
        let maxAttempts = 8
        guard attachAttemptCount < maxAttempts, !isScheduledForRetry else { return }
        attachAttemptCount += 1
        isScheduledForRetry = true
        // 4ms, 8, 16, 32, 64, 128, 256, 512 —— 总跨度约 1s。
        let delayNanoseconds = UInt64(min(1_000_000_000, 4_000_000 * (1 << (attachAttemptCount - 1))))
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(delayNanoseconds) / 1_000_000_000) { [weak self] in
            guard let self else { return }
            self.isScheduledForRetry = false
            self.attachToSplitViewIfPossible()
        }
    }

    private func cancelRetry() {
        isScheduledForRetry = false
        // asyncAfter 无法取消,但 isScheduledForRetry 标志位让过期回调变成空操作
        // (回调里会重新检查状态,且 attach 成功/窗口消失都会重置)。
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateHoverState(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if Self.verbose {
            Self.logger.info(
                "event=mouseExited orientation=\(self.splitView?.isVertical == true ? "vertical-line" : "horizontal-line", privacy: .public) hovered=\(self.isOverNativeDivider)"
            )
        }
        updateHoverState(false)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateHoverState(true)
    }

    override func cursorUpdate(with event: NSEvent) {
        super.cursorUpdate(with: event)
        updateHoverState(true)
    }

    private var resizeCursor: NSCursor? {
        guard let splitView else { return nil }
        return splitView.isVertical ? .resizeLeftRight : .resizeUpDown
    }

    private func refreshTrackingArea() {
        guard let splitView,
              let dividerIndex,
              let trackingRect = nativeDividerTrackingRect(in: splitView, at: dividerIndex)
        else { return }
        if let trackingArea {
            splitView.removeTrackingArea(trackingArea)
        }

        // `dividerThickness` is often only 1pt, while NSSplitView's native hit area is
        // wider. Measure that native area and track only it, so leaving and returning to
        // the divider always produces a fresh cursor-update event.
        let newTrackingArea = NSTrackingArea(
            rect: trackingRect,
            options: [.activeInKeyWindow, .cursorUpdate, .mouseEnteredAndExited, .mouseMoved],
            owner: self,
            userInfo: nil
        )
        splitView.addTrackingArea(newTrackingArea)
        trackingArea = newTrackingArea
        if Self.verbose {
            Self.logger.info(
                "tracking refreshed orientation=\(splitView.isVertical ? "vertical-line" : "horizontal-line", privacy: .public) rect=\(String(describing: trackingRect), privacy: .public) hovered=\(self.isOverNativeDivider)"
            )
        }

        // After a resize the tracking area is recreated, which can break mouse tracking
        // mid-drag.  Re-evaluate the hover state from the current mouse location so the
        // cursor is correct without requiring the user to leave and re-enter.
        reevaluateHoverState()
    }

    private func reevaluateHoverState() {
        guard let splitView,
              let window = splitView.window
        else { return }

        let mouseLocation = window.mouseLocationOutsideOfEventStream
        let location = splitView.convert(mouseLocation, from: nil)

        guard let dividerIndex,
              let trackingRect = nativeDividerTrackingRect(in: splitView, at: dividerIndex)
        else {
            updateHoverState(false)
            return
        }
        updateHoverState(trackingRect.contains(location))
    }

    func applyInitialPositionIfNeeded() {
        guard let splitView, let dividerIndex else { return }

        let position: CGFloat
        if let initialTrailingSize,
           !splitView.isVertical,
           initialTrailingSize.isFinite,
           initialTrailingSize > 0 {
            let availableSize = splitView.bounds.height
            guard availableSize > 0 else { return }
            position = availableSize - initialTrailingSize - splitView.dividerThickness
        } else {
            guard let initialPosition,
                  initialPosition.isFinite,
                  initialPosition > 0
            else { return }
            position = initialPosition
        }

        guard position > 0 else { return }
        if let appliedInitialPosition,
           abs(appliedInitialPosition - position) < 0.5 {
            return
        }

        let availableSize = splitView.isVertical ? splitView.bounds.width : splitView.bounds.height
        guard availableSize > 0 else { return }
        appliedInitialPosition = position
        let origin = splitView.isVertical ? splitView.bounds.minX : splitView.bounds.minY
        splitView.setPosition(origin + position, ofDividerAt: dividerIndex)
        // `setPosition` moves the native divider after the initial tracking area was
        // created. Refresh on the next run-loop turn so hover/cursor hit testing follows
        // the restored divider immediately, before the user performs the first drag.
        DispatchQueue.main.async { [weak self] in
            self?.refreshTrackingArea()
        }
        if Self.verbose {
            Self.logger.info(
                "restored divider index=\(dividerIndex) position=\(position)"
            )
        }
    }

    private func reportCurrentPosition() {
        guard let splitView, let dividerIndex else { return }
        let paneIndex = resizeTarget == .trailing ? dividerIndex + 1 : dividerIndex
        guard splitView.arrangedSubviews.indices.contains(paneIndex) else { return }
        let pane = splitView.arrangedSubviews[paneIndex]
        let position = splitView.isVertical ? pane.frame.width : pane.frame.height
        guard position.isFinite, position > 0 else { return }
        onResize?(position)
    }

    private func finishResizeIfNeeded() {
        guard isResizeGestureActive, hasPendingResize else {
            isResizeGestureActive = false
            return
        }
        isResizeGestureActive = false
        hasPendingResize = false
        // Let NSSplitView finish applying the final mouse position before reading
        // the pane frame. This produces one kernel update per completed drag.
        DispatchQueue.main.async { [weak self] in
            self?.refreshTrackingArea()
            self?.reportCurrentPosition()
        }
    }

    private func scheduleResizeCompletionCheck() {
        guard resizeCompletionWorkItem == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.resizeCompletionWorkItem = nil
            if NSEvent.pressedMouseButtons & 1 != 0 {
                self.scheduleResizeCompletionCheck()
            } else {
                self.finishResizeIfNeeded()
            }
        }
        resizeCompletionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
    }

    private func enclosingSplitView() -> NSSplitView? {
        var current = superview
        while let view = current {
            if let splitView = view as? NSSplitView,
               splitView.isVertical == edge.expectsVerticalSplit {
                return splitView
            }
            current = view.superview
        }
        return nil
    }

    private func dividerIndex(in splitView: NSSplitView) -> Int? {
        guard let paneIndex = splitView.arrangedSubviews.firstIndex(where: { isDescendant(of: $0) })
        else { return nil }

        switch edge {
        case .leading:
            guard paneIndex > 0 else { return nil }
            return paneIndex - 1
        case .trailing, .bottom:
            guard paneIndex < splitView.arrangedSubviews.count - 1 else { return nil }
            return paneIndex
        }
    }

    private func dividerRect(in splitView: NSSplitView, at index: Int) -> NSRect? {
        guard splitView.arrangedSubviews.indices.contains(index) else { return nil }
        let pane = splitView.arrangedSubviews[index]
        if splitView.isVertical {
            return NSRect(
                x: pane.frame.maxX,
                y: splitView.bounds.minY,
                width: splitView.dividerThickness,
                height: splitView.bounds.height
            )
        }
        return NSRect(
            x: splitView.bounds.minX,
            y: pane.frame.maxY,
            width: splitView.bounds.width,
            height: splitView.dividerThickness
        )
    }

    private func nativeDividerTrackingRect(in splitView: NSSplitView, at index: Int) -> NSRect? {
        guard let dividerRect = dividerRect(in: splitView, at: index) else { return nil }

        let center = splitView.isVertical ? dividerRect.midX : dividerRect.midY
        let fixedCoordinate = splitView.isVertical ? splitView.bounds.midY : splitView.bounds.midX
        let dividerLength = splitView.isVertical ? dividerRect.width : dividerRect.height
        measuredTrackingThickness = max(measuredTrackingThickness ?? 0, dividerLength)
        let step: CGFloat = 0.5
        let searchDistance: CGFloat = 12
        var matchingCoordinates: [CGFloat] = []
        var coordinate = center - searchDistance
        while coordinate <= center + searchDistance {
            let point = splitView.isVertical
                ? NSPoint(x: coordinate, y: fixedCoordinate)
                : NSPoint(x: fixedCoordinate, y: coordinate)
            if isOverNativeDivider(at: point, in: splitView) {
                matchingCoordinates.append(coordinate)
            }
            coordinate += step
        }

        guard !matchingCoordinates.isEmpty else {
            let length = measuredTrackingThickness ?? dividerLength
            let lowerBound = center - length / 2
            if splitView.isVertical {
                return NSRect(
                    x: lowerBound,
                    y: splitView.bounds.minY,
                    width: length,
                    height: splitView.bounds.height
                )
            }
            return NSRect(
                x: splitView.bounds.minX,
                y: lowerBound,
                width: splitView.bounds.width,
                height: length
            )
        }

        var runs: [[CGFloat]] = []
        for coordinate in matchingCoordinates {
            if let last = runs.indices.last,
               let previous = runs[last].last,
               coordinate - previous <= step * 1.5 {
                runs[last].append(coordinate)
            } else {
                runs.append([coordinate])
            }
        }
        func distanceFromCenter(_ run: [CGFloat]) -> CGFloat {
            let mid = ((run.first ?? center) + (run.last ?? center)) / 2
            return abs(mid - center)
        }
        guard let nearestRun = runs.min(by: { distanceFromCenter($0) < distanceFromCenter($1) }),
        let first = nearestRun.first,
        let last = nearestRun.last
        else { return dividerRect }

        let measuredLength = last - first + step
        measuredTrackingThickness = max(measuredTrackingThickness ?? 0, measuredLength)

        // During an active drag AppKit temporarily reports only the visible 1pt
        // divider from hitTest. Preserve the wider native hit area measured before
        // dragging, then recenter it on the divider's new position.
        let length = max(measuredLength, measuredTrackingThickness ?? measuredLength)
        let lowerBound = center - length / 2
        if splitView.isVertical {
            return NSRect(
                x: lowerBound,
                y: splitView.bounds.minY,
                width: length,
                height: splitView.bounds.height
            )
        }
        return NSRect(
            x: splitView.bounds.minX,
            y: lowerBound,
            width: splitView.bounds.width,
            height: length
        )
    }

    private func isOverNativeDivider(at location: NSPoint, in splitView: NSSplitView) -> Bool {
        guard splitView.bounds.contains(location),
              let hitView = splitView.hitTest(location)
        else { return false }

        let isOverPane = splitView.arrangedSubviews.contains { pane in
            hitView === pane || hitView.isDescendant(of: pane)
        }
        return !isOverPane
    }

    private func updateHoverState(_ isHovered: Bool) {
        guard isOverNativeDivider != isHovered else {
            if isHovered {
                resizeCursor?.set()
            }
            return
        }

        isOverNativeDivider = isHovered
        if Self.verbose {
            let desiredCursorIsCurrent = resizeCursor.map { NSCursor.current === $0 } ?? false
            Self.logger.info(
                "hover changed orientation=\(self.splitView?.isVertical == true ? "vertical-line" : "horizontal-line", privacy: .public) hovered=\(isHovered) desiredCursorCurrentBeforeSet=\(desiredCursorIsCurrent)"
            )
        }
        onHoverChanged?(isHovered)
        if isHovered {
            resizeCursor?.set()
        }
    }

    /// Makes the native `NSSplitView` divider visually transparent while keeping
    /// it in the view hierarchy so AppKit continues to own native divider dragging.
    private func hideNativeDivider() {
        guard let splitView else { return }
        let arranged = Set(splitView.arrangedSubviews.map { ObjectIdentifier($0) })
        for sub in splitView.subviews where !arranged.contains(ObjectIdentifier(sub)) {
            sub.alphaValue = 0
            sub.isHidden = false
        }
    }
}
#endif
