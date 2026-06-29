import AppKit
import SwiftUI

enum SplitWidth {
    static let defaultWidth: CGFloat = 280
    static let defaultMinimumWidth: CGFloat = 220
    static let defaultMaximumWidth: CGFloat = 960

    /// Clamp a requested width into `[minimum, maximum]`.
    ///
    /// Extracted from `preferredWidth` (and duplicated inline in the NSView body)
    /// so the layout bounds are testable and single-sourced.
    static func clamp(_ requested: CGFloat, minimum: CGFloat = defaultMinimumWidth, maximum: CGFloat = defaultMaximumWidth) -> CGFloat {
        min(max(requested, minimum), maximum)
    }

    static func preferredWidth(databaseDirectory: URL) -> CGFloat {
        let savedWidth = LocalStore(databaseDirectory: databaseDirectory).loadConversationListWidth()
        let requestedWidth = savedWidth > 0 ? CGFloat(savedWidth) : defaultWidth
        return clamp(requestedWidth)
    }
}

struct SplitWidthPersistence: NSViewRepresentable {
    struct Config {
        var store: LocalStore
        var defaultWidth: CGFloat
        var minimumWidth: CGFloat
        var maximumWidth: CGFloat

        static func `default`(databaseDirectory: URL) -> Config {
            Config(
                store: LocalStore(databaseDirectory: databaseDirectory),
                defaultWidth: SplitWidth.defaultWidth,
                minimumWidth: SplitWidth.defaultMinimumWidth,
                maximumWidth: SplitWidth.defaultMaximumWidth
            )
        }
    }

    let config: Config

    func makeNSView(context: Context) -> SplitWidthPersistenceView {
        SplitWidthPersistenceView(config: config)
    }

    func updateNSView(_ nsView: SplitWidthPersistenceView, context: Context) {
        nsView.config = config
    }

    static func dismantleNSView(_ nsView: SplitWidthPersistenceView, coordinator: ()) {
        nsView.detach()
    }
}

final class SplitWidthPersistenceView: NSView {
    private static let maxApplyRetryCount = 20

    var config: SplitWidthPersistence.Config {
        didSet {
            didApplyWidth = false
            applyWidthIfPossible()
        }
    }

    private weak var observedSplitView: NSSplitView?
    private var resizeObserver: NSObjectProtocol?
    private var didApplyWidth = false
    private var applyRetryCount = 0
    private var pendingRetryWorkItem: DispatchWorkItem?

    init(config: SplitWidthPersistence.Config) {
        self.config = config
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
            applyWidthIfPossible()
            return
        }

        if let resizeObserver {
            NotificationCenter.default.removeObserver(resizeObserver)
        }

        observedSplitView = splitView
        didApplyWidth = false
        applyRetryCount = 0
        applyWidthIfPossible()

        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSSplitView.didResizeSubviewsNotification,
            object: splitView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.persistCurrentWidth()
            }
        }
    }

    private func applyWidthIfPossible() {
        guard !didApplyWidth else { return }
        guard let splitView = observedSplitView ?? enclosingSplitView() else {
            scheduleRetry()
            return
        }
        guard containingColumnIndex(in: splitView) != nil,
              splitView.arrangedSubviews.count >= 2,
              splitView.isVertical
        else {
            scheduleRetry()
            return
        }

        let totalWidth = splitView.bounds.width
        guard totalWidth > 0 else {
            scheduleRetry()
            return
        }

        let dividersWidth = CGFloat(splitView.arrangedSubviews.count - 1) * splitView.dividerThickness
        let usableWidth = max(1, totalWidth - dividersWidth)
        let savedWidth = config.store.loadConversationListWidth()
        let requestedWidth = savedWidth > 0 ? CGFloat(savedWidth) : config.defaultWidth
        let otherColumnsMinimumWidth = CGFloat(splitView.arrangedSubviews.count - 1) * config.minimumWidth
        let maximumAvailableWidth = max(config.minimumWidth, usableWidth - otherColumnsMinimumWidth)
        let targetWidth = min(max(requestedWidth, config.minimumWidth), min(config.maximumWidth, maximumAvailableWidth))

        guard let currentIndex = containingColumnIndex(in: splitView) else { return }
        setColumn(currentIndex, width: targetWidth, in: splitView)
        
        // 延迟布局避免在视图层次结构构建过程中触发递归布局
        DispatchQueue.main.async {
            splitView.layoutSubtreeIfNeeded()
        }
        
        didApplyWidth = true
    }

    private func persistCurrentWidth() {
        guard let splitView = observedSplitView,
              let columnIndex = containingColumnIndex(in: splitView),
              splitView.arrangedSubviews.count > columnIndex,
              splitView.isVertical
        else { return }

        let width = splitView.arrangedSubviews[columnIndex].frame.width
        guard width.isFinite, width >= config.minimumWidth else { return }
        let clampedWidth = min(max(width, config.minimumWidth), config.maximumWidth)
        config.store.saveConversationListWidth(Double(clampedWidth))
    }

    private func setColumn(_ columnIndex: Int, width: CGFloat, in splitView: NSSplitView) {
        let dividerIndex: Int
        let position: CGFloat

        if columnIndex == splitView.arrangedSubviews.count - 1 {
            dividerIndex = max(0, columnIndex - 1)
            position = max(
                config.minimumWidth,
                splitView.bounds.width - width - splitView.dividerThickness
            )
        } else {
            dividerIndex = columnIndex
            var nextPosition: CGFloat = 0
            for index in 0..<dividerIndex {
                nextPosition += splitView.arrangedSubviews[index].frame.width
                nextPosition += splitView.dividerThickness
            }
            nextPosition += width
            position = nextPosition
        }

        splitView.setPosition(position, ofDividerAt: dividerIndex)
    }

    private func containingColumnIndex(in splitView: NSSplitView) -> Int? {
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
