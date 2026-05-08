import Foundation
import AppKit
import CodeEditSourceEditor
import CodeEditTextView

final class ScrollCoordinator: TextViewCoordinator, @unchecked Sendable {
    private weak var state: EditorState?
    private var boundsObserver: NSObjectProtocol?
    private var frameObserver: NSObjectProtocol?

    init(state: EditorState) {
        self.state = state
    }

    nonisolated func prepareCoordinator(controller: TextViewController) {
        MainActor.assumeIsolated {
            prepareOnMain(controller: controller)
        }
    }

    nonisolated func destroy() {
        MainActor.assumeIsolated {
            removeObservers()
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

        let state = self.state
        boundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                Self.publishViewportObservation(from: textView, clipView: clipView, state: state)
            }
        }

        frameObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: clipView,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                Self.publishViewportObservation(from: textView, clipView: clipView, state: state)
            }
        }

        Self.publishViewportObservation(from: textView, clipView: clipView, state: state)
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
    }

    @MainActor
    private static func publishViewportObservation(from textView: TextView, clipView: NSClipView, state: EditorState?) {
        state?.applyScrollObservation(viewportOrigin: clipView.bounds.origin)

        guard let layoutManager = textView.layoutManager else {
            state?.resetViewportObservation()
            return
        }
        guard let visibleTextRange = textView.visibleTextRange else {
            state?.resetViewportObservation(totalLines: layoutManager.lineCount)
            return
        }

        let totalLines = layoutManager.lineCount
        let startLine = layoutManager.textLineForOffset(visibleTextRange.location)?.index ?? 0
        let endOffset = max(visibleTextRange.location, visibleTextRange.max - 1)
        let endLine = layoutManager.textLineForOffset(endOffset)?.index ?? startLine
        state?.applyViewportObservation(
            startLine: startLine,
            endLine: min(totalLines, endLine + 1),
            totalLines: totalLines
        )
    }
}
