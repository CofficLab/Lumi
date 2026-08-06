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
        modifier(AppSplitDividerModifier(edge: edge))
    }
}

private struct AppSplitDividerModifier: ViewModifier {
    @LumiTheme private var theme
    @State private var isHovered = false

    let edge: AppSplitDividerEdge

    func body(content: Content) -> some View {
        content
            .background(
                AppSplitDividerHoverCoordinator(
                    edge: edge,
                    isHovered: $isHovered
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

    func makeNSView(context: Context) -> AppSplitDividerHoverCoordinatorView {
        let view = AppSplitDividerHoverCoordinatorView(edge: edge)
        view.onHoverChanged = { hovering in
            isHovered = hovering
        }
        return view
    }

    func updateNSView(_ nsView: AppSplitDividerHoverCoordinatorView, context: Context) {
        nsView.edge = edge
        nsView.onHoverChanged = { hovering in
            isHovered = hovering
        }
        nsView.attachToSplitViewIfPossible()
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
    var onHoverChanged: ((Bool) -> Void)?

    private weak var splitView: NSSplitView?
    private var dividerIndex: Int?
    private var trackingArea: NSTrackingArea?
    private var resizeObserver: NSObjectProtocol?
    private var isOverNativeDivider = false
    private var measuredTrackingThickness: CGFloat?

    init(edge: AppSplitDividerEdge) {
        self.edge = edge
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attachToSplitViewIfPossible()
    }

    func attachToSplitViewIfPossible() {
        guard window != nil else { return }
        guard let resolvedSplitView = enclosingSplitView(),
              let resolvedDividerIndex = dividerIndex(in: resolvedSplitView)
        else {
            DispatchQueue.main.async { [weak self] in
                self?.attachToSplitViewIfPossible()
            }
            return
        }

        guard splitView !== resolvedSplitView || dividerIndex != resolvedDividerIndex else {
            return
        }

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
                    Self.logger.info("didResizeSubviews refresh tracking")
                }
                self?.refreshTrackingArea()
            }
        }
        refreshTrackingArea()
        hideNativeDivider()
    }

    func detach() {
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
        dividerIndex = nil
        splitView = nil
        measuredTrackingThickness = nil
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
