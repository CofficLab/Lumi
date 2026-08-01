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
    /// - Parameter hoverSlop: Extra cursor/hover distance on each side of the visible divider.
    ///   This expands only the feedback area; `NSSplitView` still owns drag handling.
    func appSplitDivider(
        _ edge: AppSplitDividerEdge,
        hoverSlop: CGFloat = 6
    ) -> some View {
        modifier(AppSplitDividerModifier(edge: edge, hoverSlop: hoverSlop))
    }
}

private struct AppSplitDividerModifier: ViewModifier {
    @LumiTheme private var theme
    @State private var isHovered = false

    let edge: AppSplitDividerEdge
    let hoverSlop: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                AppSplitDividerHoverCoordinator(
                    edge: edge,
                    hoverSlop: hoverSlop,
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
                    colors: [.clear, .black.opacity(isHovered ? 0.22 : 0.14)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                Rectangle()
                    .fill(theme.divider)
                    .frame(height: isHovered ? 2 : 1)
                    .allowsHitTesting(false)
            }
            .frame(height: 8)
        }
    }
}

private struct AppSplitDividerHoverCoordinator: NSViewRepresentable {
    let edge: AppSplitDividerEdge
    let hoverSlop: CGFloat
    @Binding var isHovered: Bool

    func makeNSView(context: Context) -> AppSplitDividerHoverCoordinatorView {
        let view = AppSplitDividerHoverCoordinatorView(edge: edge, hoverSlop: hoverSlop)
        view.onHoverChanged = { hovering in
            isHovered = hovering
        }
        return view
    }

    func updateNSView(_ nsView: AppSplitDividerHoverCoordinatorView, context: Context) {
        nsView.edge = edge
        nsView.hoverSlop = hoverSlop
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
    var hoverSlop: CGFloat
    var onHoverChanged: ((Bool) -> Void)?

    private weak var splitView: NSSplitView?
    private var dividerIndex: Int?
    private var trackingArea: NSTrackingArea?
    private var resizeObserver: NSObjectProtocol?

    init(edge: AppSplitDividerEdge, hoverSlop: CGFloat) {
        self.edge = edge
        self.hoverSlop = hoverSlop
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
        onHoverChanged?(true)
        resizeCursor?.set()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onHoverChanged?(false)
    }

    override func cursorUpdate(with event: NSEvent) {
        super.cursorUpdate(with: event)
        resizeCursor?.set()
    }

    private var resizeCursor: NSCursor? {
        guard let splitView else { return nil }
        return splitView.isVertical ? .resizeLeftRight : .resizeUpDown
    }

    private func refreshTrackingArea() {
        guard let splitView,
              let dividerIndex,
              let dividerRect = dividerRect(in: splitView, at: dividerIndex)
        else { return }
        if let trackingArea {
            splitView.removeTrackingArea(trackingArea)
        }

        // Native divider thickness is commonly 1pt. Expand only the tracking area so users
        // discover the resize affordance sooner, while NSSplitView retains drag ownership.
        let expandedDividerRect = expandedDividerRect(dividerRect)
        let newTrackingArea = NSTrackingArea(
            rect: expandedDividerRect,
            options: [.activeInKeyWindow, .cursorUpdate, .mouseEnteredAndExited],
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
        } else {
            return NSRect(
                x: splitView.bounds.minX,
                y: pane.frame.maxY,
                width: splitView.bounds.width,
                height: splitView.dividerThickness
            )
        }
    }

    private func expandedDividerRect(_ rect: NSRect) -> NSRect {
        let distance = max(0, hoverSlop)
        if edge.expectsVerticalSplit {
            return rect.insetBy(dx: -distance, dy: 0)
        } else {
            return rect.insetBy(dx: 0, dy: -distance)
        }
    }
}
