import AppKit
import Foundation

@MainActor
final class EditorPreviewRemoteLiveCanvasService {
    private(set) var isCanvasVisible = false
    private(set) var canvasRect: CGRect = .zero
    private(set) var canvasScale: CGFloat = 1

    private var frameSyncTask: Task<Void, Never>?

    var onSyncFrame: (@MainActor (_ reason: String) async -> Void)?
    var onCaptureFrame: (@MainActor (_ reason: String) async -> Void)?
    var onHideLivePreview: (@MainActor (_ reason: String) async -> Void)?

    var canCaptureFrame: Bool {
        isCanvasVisible && !canvasRect.isEmpty
    }

    func updateCanvasRect(_ rect: CGRect, scale: CGFloat) {
        let nextRect = rect.standardized
        let nextScale = max(scale, 1)
        isCanvasVisible = true

        guard abs(nextRect.origin.x - canvasRect.origin.x) > 0.5
            || abs(nextRect.origin.y - canvasRect.origin.y) > 0.5
            || abs(nextRect.width - canvasRect.width) > 0.5
            || abs(nextRect.height - canvasRect.height) > 0.5
            || abs(nextScale - canvasScale) > 0.01 else {
            return
        }

        canvasRect = nextRect
        canvasScale = nextScale
        scheduleFrameSync(reason: "remote live canvas frame changed")
    }

    func canvasFrameUnavailable() {
        // A transient missing frame should not clear the last usable frame. The
        // preview stays anchored until SwiftUI sends an explicit disappear event.
    }

    func canvasDidAppear() {
        isCanvasVisible = true
        Task {
            await onSyncFrame?("remote live canvas appeared")
            await captureOrHide(
                captureReason: "remote live canvas appeared",
                hideReason: "remote live canvas appeared without a usable frame"
            )
        }
    }

    func canvasDidDisappear() {
        isCanvasVisible = false
        frameSyncTask?.cancel()
        frameSyncTask = nil
        Task {
            await onHideLivePreview?("remote live canvas disappeared")
        }
    }

    func cancelPendingFrameSync() {
        frameSyncTask?.cancel()
        frameSyncTask = nil
    }

    private func scheduleFrameSync(reason: String) {
        frameSyncTask?.cancel()
        frameSyncTask = Task {
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard !Task.isCancelled else { return }
            await onSyncFrame?(reason)
            await captureOrHide(
                captureReason: reason,
                hideReason: "remote live canvas frame changed without a usable frame"
            )
        }
    }

    private func captureOrHide(captureReason: String, hideReason: String) async {
        if canCaptureFrame {
            await onCaptureFrame?(captureReason)
        } else {
            await onHideLivePreview?(hideReason)
        }
    }
}
