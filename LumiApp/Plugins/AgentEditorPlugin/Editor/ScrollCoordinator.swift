import Foundation
import AppKit
import CodeEditSourceEditor
import CodeEditTextView

final class ScrollCoordinator: TextViewCoordinator {
    private weak var state: EditorState?
    private var boundsObserver: NSObjectProtocol?
    private var frameObserver: NSObjectProtocol?

    init(state: EditorState) {
        self.state = state
    }

    nonisolated func prepareCoordinator(controller: TextViewController) {
        removeObservers()

        guard let scrollView = controller.textView?.enclosingScrollView else { return }
        let clipView = scrollView.contentView
        clipView.postsBoundsChangedNotifications = true
        clipView.postsFrameChangedNotifications = true

        let state = self.state
        boundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { _ in
            state?.applyScrollObservation(viewportOrigin: clipView.bounds.origin)
        }

        frameObserver = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: clipView,
            queue: .main
        ) { _ in
            state?.applyScrollObservation(viewportOrigin: clipView.bounds.origin)
        }

        DispatchQueue.main.async {
            state?.applyScrollObservation(viewportOrigin: clipView.bounds.origin)
        }
    }

    nonisolated func destroy() {
        removeObservers()
        state = nil
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
}
