import AppKit
import SwiftUI

struct SplitViewAutosaveConfigurator: NSViewRepresentable {
    let autosaveName: String

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            enclosingSplitView(from: nsView)?.autosaveName = autosaveName
        }
    }
}

struct SplitViewWidthPersistence: NSViewRepresentable {
    let storageKey: String

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct SplitViewHeightPersistence: NSViewRepresentable {
    static let minimumHeight: CGFloat = 80
    static let maximumHeight: CGFloat = 600
    static let minimumOppositeHeight: CGFloat = 120

    @ObservedObject var layoutState: PanelLayoutState

    func makeNSView(context: Context) -> SplitViewHeightPersistenceView {
        SplitViewHeightPersistenceView(layoutState: layoutState)
    }

    func updateNSView(_ nsView: SplitViewHeightPersistenceView, context: Context) {
        nsView.layoutState = layoutState
    }

    static func dismantleNSView(_ nsView: SplitViewHeightPersistenceView, coordinator: ()) {
        nsView.detach()
    }
}

@MainActor
final class SplitViewHeightPersistenceView: NSView {
    private static let maxApplyRetryCount = 20

    var layoutState: PanelLayoutState {
        didSet {
            didApplyHeight = false
            applyHeightIfPossible()
        }
    }

    private weak var observedSplitView: NSSplitView?
    private var resizeObserver: NSObjectProtocol?
    private var didApplyHeight = false
    private var applyRetryCount = 0
    private var pendingRetryWorkItem: DispatchWorkItem?

    init(layoutState: PanelLayoutState) {
        self.layoutState = layoutState
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attachIfPossible()
    }

    func detach() {
        if let resizeObserver {
            NotificationCenter.default.removeObserver(resizeObserver)
            self.resizeObserver = nil
        }
        pendingRetryWorkItem?.cancel()
        pendingRetryWorkItem = nil
        observedSplitView = nil
    }

    private func attachIfPossible() {
        guard window != nil else { return }
        guard let splitView = enclosingSplitView() else {
            scheduleRetry()
            return
        }
        guard splitView !== observedSplitView else {
            applyHeightIfPossible()
            return
        }

        if let resizeObserver {
            NotificationCenter.default.removeObserver(resizeObserver)
        }

        observedSplitView = splitView
        didApplyHeight = false
        applyRetryCount = 0
        applyHeightIfPossible()

        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSSplitView.didResizeSubviewsNotification,
            object: splitView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.persistCurrentHeight()
            }
        }
    }

    private func applyHeightIfPossible() {
        guard !didApplyHeight else { return }
        guard let splitView = observedSplitView ?? enclosingSplitView() else {
            scheduleRetry()
            return
        }
        guard containingRowIndex(in: splitView) != nil,
              splitView.arrangedSubviews.count >= 2,
              !splitView.isVertical
        else {
            scheduleRetry()
            return
        }

        let totalHeight = splitView.bounds.height
        guard totalHeight > 0 else {
            scheduleRetry()
            return
        }

        let targetHeight = clampedHeight(
            layoutState.bottomPanelHeight,
            totalHeight: totalHeight,
            dividerCount: splitView.arrangedSubviews.count - 1,
            dividerThickness: splitView.dividerThickness
        )

        guard let rowIndex = containingRowIndex(in: splitView) else { return }
        setRow(rowIndex, height: targetHeight, in: splitView)
        splitView.layoutSubtreeIfNeeded()
        didApplyHeight = true
    }

    private func persistCurrentHeight() {
        guard let splitView = observedSplitView,
              let rowIndex = containingRowIndex(in: splitView),
              splitView.arrangedSubviews.count > rowIndex,
              !splitView.isVertical
        else { return }

        let height = splitView.arrangedSubviews[rowIndex].frame.height
        guard height.isFinite, height >= SplitViewHeightPersistence.minimumHeight else { return }

        let clamped = min(max(height, SplitViewHeightPersistence.minimumHeight), SplitViewHeightPersistence.maximumHeight)
        guard abs(layoutState.bottomPanelHeight - clamped) > 0.5 else { return }
        layoutState.bottomPanelHeight = clamped
        layoutState.persistBottomPanelHeight()
    }

    private func clampedHeight(
        _ requestedHeight: CGFloat,
        totalHeight: CGFloat,
        dividerCount: Int,
        dividerThickness: CGFloat
    ) -> CGFloat {
        let dividersHeight = CGFloat(dividerCount) * dividerThickness
        let usableHeight = max(1, totalHeight - dividersHeight)
        let maximumAvailableHeight = max(
            SplitViewHeightPersistence.minimumHeight,
            usableHeight - SplitViewHeightPersistence.minimumOppositeHeight
        )
        return min(
            max(requestedHeight, SplitViewHeightPersistence.minimumHeight),
            min(SplitViewHeightPersistence.maximumHeight, maximumAvailableHeight)
        )
    }

    private func setRow(_ rowIndex: Int, height: CGFloat, in splitView: NSSplitView) {
        let dividerIndex = max(0, rowIndex - 1)
        let position = max(
            SplitViewHeightPersistence.minimumOppositeHeight,
            splitView.bounds.height - height - splitView.dividerThickness
        )
        splitView.setPosition(position, ofDividerAt: dividerIndex)
    }

    private func containingRowIndex(in splitView: NSSplitView) -> Int? {
        splitView.arrangedSubviews.firstIndex { arrangedSubview in
            isContained(in: arrangedSubview)
        }
    }

    private func isContained(in candidateAncestor: NSView) -> Bool {
        var current: NSView? = self
        while let view = current {
            if view === candidateAncestor { return true }
            current = view.superview
        }
        return false
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

    private func scheduleRetry() {
        guard applyRetryCount < Self.maxApplyRetryCount else { return }
        pendingRetryWorkItem?.cancel()
        applyRetryCount += 1

        let workItem = DispatchWorkItem { [weak self] in
            self?.attachIfPossible()
        }
        pendingRetryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }
}

@MainActor
private func enclosingSplitView(from view: NSView) -> NSSplitView? {
    var current = view.superview
    while let view = current {
        if let splitView = view as? NSSplitView {
            return splitView
        }
        current = view.superview
    }
    return nil
}
