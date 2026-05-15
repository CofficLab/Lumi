import AppKit
import Foundation

@MainActor
final class EditorRemoteHotPreviewLiveCanvasService {
    private(set) var isCanvasVisible = false
    private(set) var canvasRect: CGRect = .zero
    private(set) var canvasScale: CGFloat = 1

    private var frameSyncTask: Task<Void, Never>?

    var onSyncFrame: (@MainActor (_ reason: String) async -> Void)?
    var onShowLivePreview: (@MainActor (_ reason: String) async -> Void)?
    var onHideLivePreview: (@MainActor (_ reason: String) async -> Void)?

    var canSyncFrame: Bool {
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
        scheduleFrameSync(reason: "hot live canvas frame changed")
    }

    func canvasFrameUnavailable() {
        // Keep the last usable frame; SwiftUI can transiently report zero rects
        // during layout without the host window actually becoming invalid.
    }

    func canvasDidAppear() {
        isCanvasVisible = true
        Task {
            if canSyncFrame {
                await onSyncFrame?("hot live canvas appeared")
                await onShowLivePreview?("hot live canvas appeared")
            }
        }
    }

    func canvasDidDisappear() {
        isCanvasVisible = false
        frameSyncTask?.cancel()
        frameSyncTask = nil
        Task {
            await onHideLivePreview?("hot live canvas disappeared")
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
            if canSyncFrame {
                await onSyncFrame?(reason)
                await onShowLivePreview?(reason)
            }
        }
    }
}
