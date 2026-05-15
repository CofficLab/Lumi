import AppKit
import SwiftUI

private let editorPreviewLiveCanvasFrameReporterFrameUpdateNotification = Notification.Name("EditorPreviewLiveCanvasFrameReporterFrameUpdate")

struct EditorPreviewLiveCanvasFrameReporter: NSViewRepresentable {
    let onFrameChange: (CGRect, CGFloat) -> Void
    let onFrameUnavailable: () -> Void

    static func scheduleFrameUpdate() {
        NotificationCenter.default.post(name: editorPreviewLiveCanvasFrameReporterFrameUpdateNotification, object: nil)
    }

    func makeNSView(context: Context) -> ReportingView {
        let view = ReportingView()
        view.onFrameChange = onFrameChange
        view.onFrameUnavailable = onFrameUnavailable
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: ReportingView, context: Context) {
        nsView.onFrameChange = onFrameChange
        nsView.onFrameUnavailable = onFrameUnavailable
        nsView.reportFrameSoon()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        private var observers: [NSObjectProtocol] = []

        func attach(to view: ReportingView) {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = [
                NotificationCenter.default.addObserver(
                    forName: NSWindow.didMoveNotification,
                    object: nil,
                    queue: .main
                ) { [weak view] notification in
                    guard let window = notification.object as? NSWindow,
                          window === view?.window else { return }
                    Task { @MainActor in
                        view?.reportFrameSoon()
                    }
                },
                NotificationCenter.default.addObserver(
                    forName: NSWindow.didResizeNotification,
                    object: nil,
                    queue: .main
                ) { [weak view] notification in
                    guard let window = notification.object as? NSWindow,
                          window === view?.window else { return }
                    Task { @MainActor in
                        view?.reportFrameSoon()
                    }
                },
                NotificationCenter.default.addObserver(
                    forName: NSWindow.didChangeScreenNotification,
                    object: nil,
                    queue: .main
                ) { [weak view] notification in
                    guard let window = notification.object as? NSWindow,
                          window === view?.window else { return }
                    Task { @MainActor in
                        view?.reportFrameSoon()
                    }
                },
                NotificationCenter.default.addObserver(
                    forName: NSWindow.didChangeBackingPropertiesNotification,
                    object: nil,
                    queue: .main
                ) { [weak view] notification in
                    guard let window = notification.object as? NSWindow,
                          window === view?.window else { return }
                    Task { @MainActor in
                        view?.reportFrameSoon()
                    }
                },
                NotificationCenter.default.addObserver(
                    forName: NSApplication.didChangeScreenParametersNotification,
                    object: nil,
                    queue: .main
                ) { [weak view] _ in
                    Task { @MainActor in
                        view?.reportFrameSoon()
                    }
                },
                NotificationCenter.default.addObserver(
                    forName: editorPreviewLiveCanvasFrameReporterFrameUpdateNotification,
                    object: nil,
                    queue: .main
                ) { [weak view] _ in
                    Task { @MainActor in
                        view?.reportFrameSoon()
                    }
                }
            ]
        }

        deinit {
            observers.forEach(NotificationCenter.default.removeObserver)
        }
    }

    final class ReportingView: NSView {
        var onFrameChange: ((CGRect, CGFloat) -> Void)?
        var onFrameUnavailable: (() -> Void)?
        private var lastReportedFrame: CGRect = .null

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            reportFrameSoon()
        }

        override func setFrameSize(_ newSize: NSSize) {
            super.setFrameSize(newSize)
            reportFrameSoon()
        }

        func reportFrameSoon() {
            DispatchQueue.main.async { [weak self] in
                self?.reportFrame()
            }
        }

        private func reportFrame() {
            let visibleBounds = bounds.intersection(visibleRect)
            guard let window, !visibleBounds.isEmpty, !hasHiddenAncestor else {
                guard lastReportedFrame != .null else { return }
                lastReportedFrame = .null
                onFrameUnavailable?()
                return
            }
            let windowRect = convert(visibleBounds, to: nil)
            let screenRect = window.convertToScreen(windowRect).standardized
            guard screenRect != lastReportedFrame else { return }
            lastReportedFrame = screenRect
            onFrameChange?(screenRect, window.backingScaleFactor)
        }

        private var hasHiddenAncestor: Bool {
            var view: NSView? = self
            while let current = view {
                if current.isHidden {
                    return true
                }
                view = current.superview
            }
            return false
        }
    }
}

struct EditorPreviewWindowLifecycleReporter: NSViewRepresentable {
    let onWindowBecameActive: () -> Void
    let onWindowBecameInactive: () -> Void
    let onWindowMiniaturized: () -> Void
    let onWindowDeminiaturized: () -> Void
    let onWindowFrameChanged: () -> Void
    let onWindowVisibilityChanged: (Bool) -> Void
    let onWindowInteraction: () -> Void

    func makeNSView(context: Context) -> ReportingView {
        let view = ReportingView()
        view.onWindowBecameActive = onWindowBecameActive
        view.onWindowBecameInactive = onWindowBecameInactive
        view.onWindowMiniaturized = onWindowMiniaturized
        view.onWindowDeminiaturized = onWindowDeminiaturized
        view.onWindowFrameChanged = onWindowFrameChanged
        view.onWindowVisibilityChanged = onWindowVisibilityChanged
        view.onWindowInteraction = onWindowInteraction
        return view
    }

    func updateNSView(_ nsView: ReportingView, context: Context) {
        nsView.onWindowBecameActive = onWindowBecameActive
        nsView.onWindowBecameInactive = onWindowBecameInactive
        nsView.onWindowMiniaturized = onWindowMiniaturized
        nsView.onWindowDeminiaturized = onWindowDeminiaturized
        nsView.onWindowFrameChanged = onWindowFrameChanged
        nsView.onWindowVisibilityChanged = onWindowVisibilityChanged
        nsView.onWindowInteraction = onWindowInteraction
        nsView.attachToCurrentWindow()
    }

    final class ReportingView: NSView {
        var onWindowBecameActive: (() -> Void)?
        var onWindowBecameInactive: (() -> Void)?
        var onWindowMiniaturized: (() -> Void)?
        var onWindowDeminiaturized: (() -> Void)?
        var onWindowFrameChanged: (() -> Void)?
        var onWindowVisibilityChanged: ((Bool) -> Void)?
        var onWindowInteraction: (() -> Void)?

        private weak var observedWindow: NSWindow?
        nonisolated(unsafe) private var localMouseMonitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            attachToCurrentWindow()
        }

        func attachToCurrentWindow() {
            guard observedWindow !== window else { return }
            NotificationCenter.default.removeObserver(self)
            removeLocalMouseMonitor()
            observedWindow = window

            guard let window else {
                onWindowBecameInactive?()
                return
            }

            notifyWindowVisibilityChanged()

            let center = NotificationCenter.default
            center.addObserver(self, selector: #selector(windowDidBecomeKey), name: NSWindow.didBecomeKeyNotification, object: window)
            center.addObserver(self, selector: #selector(windowDidResignKey), name: NSWindow.didResignKeyNotification, object: window)
            center.addObserver(self, selector: #selector(windowOcclusionStateChanged), name: NSWindow.didChangeOcclusionStateNotification, object: window)
            center.addObserver(self, selector: #selector(windowDidMiniaturize), name: NSWindow.didMiniaturizeNotification, object: window)
            center.addObserver(self, selector: #selector(windowWillClose), name: NSWindow.willCloseNotification, object: window)
            center.addObserver(self, selector: #selector(windowDidDeminiaturize), name: NSWindow.didDeminiaturizeNotification, object: window)
            center.addObserver(self, selector: #selector(windowFrameChanged), name: NSWindow.didMoveNotification, object: window)
            center.addObserver(self, selector: #selector(windowFrameChanged), name: NSWindow.didResizeNotification, object: window)
            center.addObserver(self, selector: #selector(windowFrameChanged), name: NSWindow.didChangeScreenNotification, object: window)
            center.addObserver(self, selector: #selector(windowFrameChanged), name: NSWindow.didChangeBackingPropertiesNotification, object: window)
            center.addObserver(self, selector: #selector(windowFrameChanged), name: NSWindow.didEnterFullScreenNotification, object: window)
            center.addObserver(self, selector: #selector(windowFrameChanged), name: NSWindow.didExitFullScreenNotification, object: window)
            center.addObserver(self, selector: #selector(screenParametersChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
            center.addObserver(self, selector: #selector(applicationActiveStateChanged), name: NSApplication.didBecomeActiveNotification, object: nil)
            center.addObserver(self, selector: #selector(applicationActiveStateChanged), name: NSApplication.didResignActiveNotification, object: nil)

            localMouseMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            ) { [weak self] event in
                guard let self, event.window === self.observedWindow else { return event }
                DispatchQueue.main.async { [weak self] in
                    self?.onWindowInteraction?()
                }
                return event
            }
        }

        @objc private func windowDidBecomeKey() {
            onWindowBecameActive?()
            onWindowFrameChanged?()
        }

        @objc private func windowDidResignKey() {
            scheduleWindowVisibilityRefresh()
            onWindowFrameChanged?()
        }

        @objc private func windowDidMiniaturize() {
            onWindowBecameInactive?()
            onWindowVisibilityChanged?(false)
            onWindowMiniaturized?()
        }

        @objc private func windowWillClose() {
            onWindowBecameInactive?()
            onWindowVisibilityChanged?(false)
        }

        @objc private func windowDidDeminiaturize() {
            notifyWindowVisibilityChanged()
            onWindowDeminiaturized?()
            onWindowFrameChanged?()
        }

        @objc private func windowFrameChanged() {
            onWindowFrameChanged?()
        }

        @objc private func screenParametersChanged() {
            onWindowFrameChanged?()
            scheduleWindowVisibilityRefresh()
        }

        @objc private func windowOcclusionStateChanged() {
            notifyWindowVisibilityChanged()
            onWindowFrameChanged?()
        }

        @objc private func applicationActiveStateChanged() {
            scheduleWindowVisibilityRefresh()
        }

        private var isObservedWindowVisible: Bool {
            guard let window = observedWindow else { return false }
            return window.isVisible
                && !window.isMiniaturized
                && window.occlusionState.contains(.visible)
        }

        private func notifyWindowVisibilityChanged() {
            onWindowVisibilityChanged?(isObservedWindowVisible)
        }

        private func scheduleWindowVisibilityRefresh() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                self?.notifyWindowVisibilityChanged()
            }
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
            if let localMouseMonitor {
                NSEvent.removeMonitor(localMouseMonitor)
            }
        }

        private func removeLocalMouseMonitor() {
            if let localMouseMonitor {
                NSEvent.removeMonitor(localMouseMonitor)
                self.localMouseMonitor = nil
            }
        }
    }
}
