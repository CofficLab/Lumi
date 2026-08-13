#if canImport(AppKit)
import AppKit
import OSLog
import SwiftUI

/// The edge of the pane that owns a split-view divider.
///
/// Apply ``View/appSplitDivider(_:)`` to the leading pane of an `HSplitView`
/// or the top pane of a `VSplitView`.
public enum AppSplitDividerEdge: Sendable {
    case trailing
    case bottom

    fileprivate var alignment: Alignment {
        switch self {
        case .trailing: .trailing
        case .bottom: .bottom
        }
    }

    fileprivate var expectsVerticalSplit: Bool {
        switch self {
        case .trailing: true
        case .bottom: false
        }
    }
}

public extension View {
    /// Adds Lumi's interactive styling to the divider following this pane.
    ///
    /// The divider gets a subtle inset shadow, becomes more prominent on hover,
    /// and uses the matching resize cursor without intercepting native dragging.
    /// Hover feedback is limited to the native draggable area so the cursor never
    /// advertises resizing where `NSSplitView` cannot begin a drag.
    func appSplitDivider(_ edge: AppSplitDividerEdge) -> some View {
        appSplitDivider(edge, initialPosition: nil, onResize: nil)
    }

    /// Adds interactive styling, restores the divider once after attachment, and
    /// reports the leading pane's native size after resize.
    func appSplitDivider(
        _ edge: AppSplitDividerEdge,
        initialPosition: CGFloat? = nil,
        onResize: (@MainActor (CGFloat) -> Void)?
    ) -> some View {
        modifier(
            AppSplitDividerModifier(
                edge: edge,
                initialPosition: initialPosition,
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
    let onResize: (@MainActor (CGFloat) -> Void)?

    func body(content: Content) -> some View {
        content
            .background(
                AppSplitDividerHoverCoordinator(
                    edge: edge,
                    isHovered: $isHovered,
                    initialPosition: initialPosition,
                    onResize: onResize
                )
            )
            .overlay(alignment: edge.alignment) {
                dividerDecoration
            }
    }

    @ViewBuilder
    private var dividerDecoration: some View {
        switch edge {
        case .trailing:
            ZStack(alignment: .trailing) {
                LinearGradient(
                    colors: [.clear, .black.opacity(isHovered ? 0.1 : 0.04)],
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
                    colors: [.clear, .black.opacity(isHovered ? 0.1 : 0.04)],
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
}

private struct AppSplitDividerHoverCoordinator: NSViewRepresentable {
    let edge: AppSplitDividerEdge
    @Binding var isHovered: Bool
    let initialPosition: CGFloat?
    let onResize: (@MainActor (CGFloat) -> Void)?

    func makeNSView(context: Context) -> AppSplitDividerHoverCoordinatorView {
        let view = AppSplitDividerHoverCoordinatorView(
            edge: edge,
            initialPosition: initialPosition,
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
        nsView.detach()
    }
}

@MainActor
private final class AppSplitDividerHoverCoordinatorView: NSView {
    private static let verbose = false
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "split-divider")

    var edge: AppSplitDividerEdge
    var initialPosition: CGFloat?
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
        onResize: (@MainActor (CGFloat) -> Void)? = nil
    ) {
        self.edge = edge
        self.initialPosition = initialPosition
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
        guard let splitView, let dividerIndex, let initialPosition,
              initialPosition.isFinite, initialPosition > 0
        else { return }
        if let appliedInitialPosition,
           abs(appliedInitialPosition - initialPosition) < 0.5 {
            return
        }

        let availableSize = splitView.isVertical ? splitView.bounds.width : splitView.bounds.height
        guard availableSize > 0 else { return }
        appliedInitialPosition = initialPosition
        let origin = splitView.isVertical ? splitView.bounds.minX : splitView.bounds.minY
        splitView.setPosition(origin + initialPosition, ofDividerAt: dividerIndex)
        // `setPosition` moves the native divider after the initial tracking area was
        // created. Refresh on the next run-loop turn so hover/cursor hit testing follows
        // the restored divider immediately, before the user performs the first drag.
        DispatchQueue.main.async { [weak self] in
            self?.refreshTrackingArea()
        }
        if Self.verbose {
            Self.logger.info(
                "restored divider index=\(dividerIndex) position=\(initialPosition)"
            )
        }
    }

    private func reportCurrentPosition() {
        guard let splitView, let dividerIndex,
              splitView.arrangedSubviews.indices.contains(dividerIndex)
        else { return }
        let pane = splitView.arrangedSubviews[dividerIndex]
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
        guard let paneIndex = splitView.arrangedSubviews.firstIndex(where: { isDescendant(of: $0) }),
              paneIndex < splitView.arrangedSubviews.count - 1
        else { return nil }
        return paneIndex
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
