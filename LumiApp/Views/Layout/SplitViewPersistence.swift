import AppKit
import LumiCoreKit
import SwiftUI

struct SplitDimensionConstraints: Equatable {
    var defaultSize: CGFloat
    var minSize: CGFloat
    var maxSize: CGFloat
    var minimumOppositeSize: CGFloat

    static let rail = SplitDimensionConstraints(
        defaultSize: 240,
        minSize: 180,
        maxSize: 480,
        minimumOppositeSize: 280
    )

    static let bottomPanel = SplitDimensionConstraints(
        defaultSize: 200,
        minSize: 80,
        maxSize: 600,
        minimumOppositeSize: 120
    )

    static func chatSection(_ layout: LumiChatSectionLayout) -> SplitDimensionConstraints {
        SplitDimensionConstraints(
            defaultSize: layout.defaultWidth,
            minSize: layout.minWidth,
            maxSize: layout.maximumWidth,
            minimumOppositeSize: layout.minimumRemainingWidth
        )
    }
}

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

struct SplitDimensionPersistence: NSViewRepresentable {
    enum Axis {
        case horizontal
        case vertical
    }

    let storageKey: String
    let constraints: SplitDimensionConstraints
    let axis: Axis

    func makeNSView(context: Context) -> SplitDimensionPersistenceView {
        SplitDimensionPersistenceView(
            storageKey: storageKey,
            constraints: constraints,
            axis: axis
        )
    }

    func updateNSView(_ nsView: SplitDimensionPersistenceView, context: Context) {
        nsView.updateConfiguration(
            storageKey: storageKey,
            constraints: constraints,
            axis: axis
        )
    }

    static func dismantleNSView(_ nsView: SplitDimensionPersistenceView, coordinator: ()) {
        nsView.detach()
    }
}

struct SplitViewWidthPersistence: NSViewRepresentable {
    let storageKey: String
    var constraints: SplitDimensionConstraints = .rail

    func makeNSView(context: Context) -> SplitDimensionPersistenceView {
        SplitDimensionPersistenceView(
            storageKey: storageKey,
            constraints: constraints,
            axis: .horizontal
        )
    }

    func updateNSView(_ nsView: SplitDimensionPersistenceView, context: Context) {
        nsView.updateConfiguration(
            storageKey: storageKey,
            constraints: constraints,
            axis: .horizontal
        )
    }

    static func dismantleNSView(_ nsView: SplitDimensionPersistenceView, coordinator: ()) {
        nsView.detach()
    }
}

struct ChatSectionWidthPersistence: NSViewRepresentable {
    let layout: LumiChatSectionLayout
    let storageKey: String

    func makeNSView(context: Context) -> SplitDimensionPersistenceView {
        SplitDimensionPersistenceView(
            storageKey: storageKey,
            constraints: .chatSection(layout),
            axis: .horizontal
        )
    }

    func updateNSView(_ nsView: SplitDimensionPersistenceView, context: Context) {
        nsView.updateConfiguration(
            storageKey: storageKey,
            constraints: .chatSection(layout),
            axis: .horizontal
        )
    }

    static func dismantleNSView(_ nsView: SplitDimensionPersistenceView, coordinator: ()) {
        nsView.detach()
    }
}

struct SplitViewHeightPersistence: NSViewRepresentable {
    static let minimumHeight = SplitDimensionConstraints.bottomPanel.minSize
    static let maximumHeight = SplitDimensionConstraints.bottomPanel.maxSize
    static let minimumOppositeHeight = SplitDimensionConstraints.bottomPanel.minimumOppositeSize

    let storageKey: String
    var constraints: SplitDimensionConstraints = .bottomPanel

    func makeNSView(context: Context) -> SplitDimensionPersistenceView {
        SplitDimensionPersistenceView(
            storageKey: storageKey,
            constraints: constraints,
            axis: .vertical
        )
    }

    func updateNSView(_ nsView: SplitDimensionPersistenceView, context: Context) {
        nsView.updateConfiguration(
            storageKey: storageKey,
            constraints: constraints,
            axis: .vertical
        )
    }

    static func dismantleNSView(_ nsView: SplitDimensionPersistenceView, coordinator: ()) {
        nsView.detach()
    }
}

@MainActor
final class SplitDimensionPersistenceView: NSView {
    private static let maxApplyRetryCount = 20

    private var storageKey: String
    private var dimensionConstraints: SplitDimensionConstraints
    private var axis: SplitDimensionPersistence.Axis

    private weak var observedSplitView: NSSplitView?
    private var resizeObserver: NSObjectProtocol?
    private var didApplySize = false
    private var applyRetryCount = 0
    private var pendingRetryWorkItem: DispatchWorkItem?

    init(
        storageKey: String,
        constraints: SplitDimensionConstraints,
        axis: SplitDimensionPersistence.Axis
    ) {
        self.storageKey = storageKey
        self.dimensionConstraints = constraints
        self.axis = axis
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateConfiguration(
        storageKey: String,
        constraints: SplitDimensionConstraints,
        axis: SplitDimensionPersistence.Axis
    ) {
        guard self.storageKey != storageKey
            || self.dimensionConstraints != constraints
            || self.axis != axis
        else { return }

        self.storageKey = storageKey
        self.dimensionConstraints = constraints
        self.axis = axis
        didApplySize = false
        applySizeIfPossible()
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
            applySizeIfPossible()
            return
        }

        if let resizeObserver {
            NotificationCenter.default.removeObserver(resizeObserver)
        }

        observedSplitView = splitView
        didApplySize = false
        applyRetryCount = 0
        applySizeIfPossible()

        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSSplitView.didResizeSubviewsNotification,
            object: splitView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.persistCurrentSize()
            }
        }
    }

    private func applySizeIfPossible() {
        guard !didApplySize else { return }
        guard let splitView = observedSplitView ?? enclosingSplitView() else {
            scheduleRetry()
            return
        }
        guard containingPaneIndex(in: splitView) != nil,
              splitView.arrangedSubviews.count >= 2,
              splitView.isVertical == (axis == .horizontal)
        else {
            scheduleRetry()
            return
        }

        let totalSize = axis == .horizontal ? splitView.bounds.width : splitView.bounds.height
        guard totalSize > 0 else {
            scheduleRetry()
            return
        }

        let savedSize = UserDefaults.standard.object(forKey: storageKey) as? Double
        let requestedSize = savedSize.map { CGFloat($0) } ?? dimensionConstraints.defaultSize
        let targetSize = clampedSize(
            requestedSize,
            totalSize: totalSize,
            dividerCount: splitView.arrangedSubviews.count - 1,
            dividerThickness: splitView.dividerThickness
        )

        guard let paneIndex = containingPaneIndex(in: splitView) else { return }
        setPane(paneIndex, size: targetSize, in: splitView)
        
        // 延迟布局避免在视图层次结构构建过程中触发递归布局
        DispatchQueue.main.async {
            splitView.layoutSubtreeIfNeeded()
        }
        
        didApplySize = true
    }

    private func persistCurrentSize() {
        guard let splitView = observedSplitView,
              let paneIndex = containingPaneIndex(in: splitView),
              splitView.arrangedSubviews.count > paneIndex,
              splitView.isVertical == (axis == .horizontal)
        else { return }

        let paneSize = axis == .horizontal
            ? splitView.arrangedSubviews[paneIndex].frame.width
            : splitView.arrangedSubviews[paneIndex].frame.height
        guard paneSize.isFinite, paneSize >= dimensionConstraints.minSize else { return }

        let clamped = min(max(paneSize, dimensionConstraints.minSize), dimensionConstraints.maxSize)
        let saved = UserDefaults.standard.double(forKey: storageKey)
        guard abs(saved - Double(clamped)) > 0.5 else { return }
        UserDefaults.standard.set(Double(clamped), forKey: storageKey)
    }

    private func clampedSize(
        _ requestedSize: CGFloat,
        totalSize: CGFloat,
        dividerCount: Int,
        dividerThickness: CGFloat
    ) -> CGFloat {
        let dividersSize = CGFloat(dividerCount) * dividerThickness
        let usableSize = max(1, totalSize - dividersSize)
        let maximumAvailableSize = max(
            dimensionConstraints.minSize,
            usableSize - dimensionConstraints.minimumOppositeSize
        )
        return min(
            max(requestedSize, dimensionConstraints.minSize),
            min(dimensionConstraints.maxSize, maximumAvailableSize)
        )
    }

    private func setPane(_ paneIndex: Int, size: CGFloat, in splitView: NSSplitView) {
        let dividerIndex: Int
        let position: CGFloat
        let totalSize = axis == .horizontal ? splitView.bounds.width : splitView.bounds.height

        if paneIndex == splitView.arrangedSubviews.count - 1 {
            dividerIndex = max(0, paneIndex - 1)
            position = max(
                dimensionConstraints.minimumOppositeSize,
                totalSize - size - splitView.dividerThickness
            )
        } else if axis == .vertical {
            dividerIndex = max(0, paneIndex - 1)
            position = max(
                dimensionConstraints.minimumOppositeSize,
                totalSize - size - splitView.dividerThickness
            )
        } else {
            dividerIndex = paneIndex
            var nextPosition: CGFloat = 0
            for index in 0..<dividerIndex {
                nextPosition += splitView.arrangedSubviews[index].frame.width
                nextPosition += splitView.dividerThickness
            }
            nextPosition += size
            position = nextPosition
        }

        splitView.setPosition(position, ofDividerAt: dividerIndex)
    }

    private func containingPaneIndex(in splitView: NSSplitView) -> Int? {
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
