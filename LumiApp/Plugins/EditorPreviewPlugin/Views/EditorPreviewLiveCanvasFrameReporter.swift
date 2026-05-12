#if canImport(LumiPreviewKit)
import AppKit
import SwiftUI

private let editorPreviewLiveCanvasFrameReporterFrameUpdateNotification = Notification.Name("EditorPreviewLiveCanvasFrameReporterFrameUpdate")

struct EditorPreviewLiveCanvasFrameReporter: NSViewRepresentable {
    let onFrameChange: (CGRect) -> Void

    static func scheduleFrameUpdate() {
        NotificationCenter.default.post(name: editorPreviewLiveCanvasFrameReporterFrameUpdateNotification, object: nil)
    }

    func makeNSView(context: Context) -> ReportingView {
        let view = ReportingView()
        view.onFrameChange = onFrameChange
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: ReportingView, context: Context) {
        nsView.onFrameChange = onFrameChange
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
                ) { [weak view] _ in
                    Task { @MainActor in
                        view?.reportFrameSoon()
                    }
                },
                NotificationCenter.default.addObserver(
                    forName: NSWindow.didResizeNotification,
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
        var onFrameChange: ((CGRect) -> Void)?
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
            guard let window, !bounds.isEmpty else { return }
            let windowRect = convert(bounds, to: nil)
            let screenRect = window.convertToScreen(windowRect).standardized
            guard screenRect != lastReportedFrame else { return }
            lastReportedFrame = screenRect
            onFrameChange?(screenRect)
        }
    }
}
#endif
