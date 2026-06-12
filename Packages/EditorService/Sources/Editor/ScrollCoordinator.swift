import Foundation
import AppKit
import EditorSource
import EditorTextView

public final class ScrollCoordinator: TextViewCoordinator, @unchecked Sendable {
    private weak var state: EditorState?
    private var boundsObserver: NSObjectProtocol?
    private var frameObserver: NSObjectProtocol?
    private var scrollPersistenceTask: Task<Void, Never>?
    private var lastViewportObservation: ViewportObservation?
    private var lastPersistedScrollOrigin: CGPoint?

    private static let scrollPersistenceDelayNs: UInt64 = 160_000_000
    private static let scrollOriginTolerance: CGFloat = 0.5

    private struct ViewportObservation: Equatable {
        let startLine: Int
        let endLine: Int
        let totalLines: Int
    }

    public init(state: EditorState) {
        self.state = state
    }

    public nonisolated func prepareCoordinator(controller: TextViewController) {
        MainActor.assumeIsolated {
            prepareOnMain(controller: controller)
        }
    }

    public nonisolated func destroy() {
        MainActor.assumeIsolated {
            removeObservers()
            scrollPersistenceTask?.cancel()
            scrollPersistenceTask = nil
            state = nil
        }
    }

    @MainActor
    private func prepareOnMain(controller: TextViewController) {
        removeObservers()

        guard let textView = controller.textView,
              let scrollView = textView.enclosingScrollView else { return }
        let clipView = scrollView.contentView
        clipView.postsBoundsChangedNotifications = true
        clipView.postsFrameChangedNotifications = true

        boundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleScrollEvent(from: textView, clipView: clipView)
            }
        }

        frameObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleScrollEvent(from: textView, clipView: clipView)
            }
        }

        handleScrollEvent(from: textView, clipView: clipView, persistImmediately: true)
    }

    private func removeObservers() {
        if let boundsObserver {
            NotificationCenter.default.removeObserver(boundsObserver)
            self.boundsObserver = nil
        }
        if let frameObserver {
            NotificationCenter.default.removeObserver(frameObserver)
            self.frameObserver = nil
        }
        scrollPersistenceTask?.cancel()
        scrollPersistenceTask = nil
        lastViewportObservation = nil
        lastPersistedScrollOrigin = nil
    }

    @MainActor
    private func handleScrollEvent(
        from textView: TextView,
        clipView: NSClipView,
        persistImmediately: Bool = false
    ) {
        let origin = clipView.bounds.origin
        if persistImmediately {
            persistScrollOrigin(origin)
        } else {
            scheduleScrollPersistence(origin)
        }

        publishViewportObservation(from: textView)
    }

    @MainActor
    private func scheduleScrollPersistence(_ origin: CGPoint) {
        guard shouldPersistScrollOrigin(origin) else { return }

        scrollPersistenceTask?.cancel()
        scrollPersistenceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.scrollPersistenceDelayNs)
            guard !Task.isCancelled else { return }
            self?.persistScrollOrigin(origin)
        }
    }

    @MainActor
    private func persistScrollOrigin(_ origin: CGPoint) {
        guard shouldPersistScrollOrigin(origin) else { return }
        lastPersistedScrollOrigin = origin
        state?.persistScrollObservation(viewportOrigin: origin)
    }

    @MainActor
    private func shouldPersistScrollOrigin(_ origin: CGPoint) -> Bool {
        guard let lastPersistedScrollOrigin else { return true }
        return abs(lastPersistedScrollOrigin.x - origin.x) >= Self.scrollOriginTolerance
            || abs(lastPersistedScrollOrigin.y - origin.y) >= Self.scrollOriginTolerance
    }

    @MainActor
    private func publishViewportObservation(from textView: TextView) {
        guard let layoutManager = textView.layoutManager else {
            publishViewportObservation(ViewportObservation(startLine: 0, endLine: 0, totalLines: 0), reset: true)
            return
        }
        guard let visibleTextRange = textView.visibleTextRange else {
            publishViewportObservation(
                ViewportObservation(startLine: 0, endLine: 0, totalLines: layoutManager.lineCount),
                reset: true
            )
            return
        }

        let totalLines = layoutManager.lineCount
        let startLine = layoutManager.textLineForOffset(visibleTextRange.location)?.index ?? 0
        let endOffset = max(visibleTextRange.location, visibleTextRange.max - 1)
        let endLine = layoutManager.textLineForOffset(endOffset)?.index ?? startLine
        publishViewportObservation(
            ViewportObservation(
                startLine: startLine,
                endLine: min(totalLines, endLine + 1),
                totalLines: totalLines
            )
        )
    }

    @MainActor
    private func publishViewportObservation(_ observation: ViewportObservation, reset: Bool = false) {
        guard observation != lastViewportObservation else { return }
        lastViewportObservation = observation

        if reset {
            state?.resetViewportObservation(totalLines: observation.totalLines)
        } else {
            state?.applyViewportObservation(
                startLine: observation.startLine,
                endLine: observation.endLine,
                totalLines: observation.totalLines
            )
        }
    }
}
