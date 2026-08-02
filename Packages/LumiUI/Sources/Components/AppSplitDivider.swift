import AppKit
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
                    .frame(width: isHovered ? 0.4 : 0.2)
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
                    .frame(height: isHovered ? 0.4 : 0.2)
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
    var edge: AppSplitDividerEdge
    var onHoverChanged: ((Bool) -> Void)?

    private weak var splitView: NSSplitView?
    private var dividerIndex: Int?
    private var trackingArea: NSTrackingArea?
    private var resizeObserver: NSObjectProtocol?
    private var isOverNativeDivider = false

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
            refreshTrackingArea()
            return
        }

        detach()
        splitView = resolvedSplitView
        dividerIndex = resolvedDividerIndex
        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSSplitView.didResizeSubviewsNotification,
            object: resolvedSplitView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshTrackingArea()
            }
        }
        refreshTrackingArea()
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
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateHoverState(for: event)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        updateHoverState(false)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateHoverState(for: event)
    }

    override func cursorUpdate(with event: NSEvent) {
        super.cursorUpdate(with: event)
        updateHoverState(for: event)
    }

    private var resizeCursor: NSCursor? {
        guard let splitView else { return nil }
        return splitView.isVertical ? .resizeLeftRight : .resizeUpDown
    }

    private func refreshTrackingArea() {
        guard let splitView,
              dividerIndex != nil
        else { return }
        if let trackingArea {
            splitView.removeTrackingArea(trackingArea)
        }

        // Track the full split view, then use hitTest below to identify the exact native
        // divider hit-area. This keeps the resize cursor and draggable region aligned.
        let newTrackingArea = NSTrackingArea(
            rect: splitView.bounds,
            options: [.activeInKeyWindow, .cursorUpdate, .mouseEnteredAndExited, .mouseMoved],
            owner: self,
            userInfo: nil
        )
        splitView.addTrackingArea(newTrackingArea)
        trackingArea = newTrackingArea
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

    private func updateHoverState(for event: NSEvent) {
        guard let splitView else {
            updateHoverState(false)
            return
        }

        let location = splitView.convert(event.locationInWindow, from: nil)
        let hitView = splitView.hitTest(location)
        let isOverPane = splitView.arrangedSubviews.contains { pane in
            guard let hitView else { return false }
            return hitView === pane || hitView.isDescendant(of: pane)
        }
        updateHoverState(!isOverPane)
    }

    private func updateHoverState(_ isHovered: Bool) {
        guard isOverNativeDivider != isHovered else {
            if isHovered {
                resizeCursor?.set()
            }
            return
        }

        isOverNativeDivider = isHovered
        onHoverChanged?(isHovered)
        if isHovered {
            resizeCursor?.set()
        }
    }
}
