import AppKit
import Foundation

public extension LumiPreviewFacade {
    /// 编辑器预览 Live Canvas 可见性与帧同步服务。
    ///
    /// 管理 Live 预览窗口的显示/隐藏状态逻辑，包括：
    /// - Canvas 可见性和帧矩形跟踪
    /// - 根据综合条件决定是否显示/隐藏 Live 窗口
    @MainActor
    final class LiveCanvasService {
        /// Canvas 是否可见。
        public private(set) var isLiveCanvasVisible: Bool = false

        /// Canvas 在屏幕坐标系中的矩形。
        public private(set) var liveCanvasRect: CGRect = .zero

        /// Canvas 所在屏幕 scale factor。
        public private(set) var liveCanvasScale: CGFloat = 1

        /// 当前显示模式。
        public private(set) var displayMode: PreviewDisplayMode

        /// Owning app/window 是否处于可显示 live preview 的前台状态。
        public private(set) var isAppActive: Bool = true

        /// 帧同步防抖 Task。
        private var liveFrameSyncTask: Task<Void, Never>?
        private var needsShowWhenFrameAvailable = false

        /// 触发 Live 预览帧同步的回调。
        public var onSyncLiveFrameFromEngine: (@MainActor (_ reason: String) async -> Void)?

        /// 触发 Live 窗口显示的回调。
        public var onShowLivePreview: (@MainActor (_ reason: String) async -> Void)?

        /// 触发 Live 窗口隐藏的回调。
        public var onHideLivePreview: (@MainActor (_ reason: String) async -> Void)?

        public init(displayMode: PreviewDisplayMode) {
            self.displayMode = displayMode
        }

        /// Compatibility alias for older editor integration code.
        public var isCanvasVisible: Bool {
            isLiveCanvasVisible
        }

        /// Compatibility alias for older editor integration code.
        public var canvasRect: CGRect {
            liveCanvasRect
        }

        /// Compatibility alias for older editor integration code.
        public var canvasScale: CGFloat {
            liveCanvasScale
        }

        /// Compatibility alias for older editor integration code.
        public var canSyncFrame: Bool {
            isLiveCanvasVisible && !liveCanvasRect.isEmpty
        }

        /// 是否具备显示 Live 窗口的全部条件。
        public var shouldShowLiveWindow: Bool {
            displayMode == .live
                && isAppActive
                && isLiveCanvasVisible
                && !liveCanvasRect.isEmpty
        }

        /// 更新显示模式。
        public func updateDisplayMode(_ mode: PreviewDisplayMode) {
            displayMode = mode
        }

        /// 更新 Canvas 可见性，不立即触发显隐同步。
        public func updateLiveCanvasVisibility(_ isVisible: Bool) {
            isLiveCanvasVisible = isVisible
        }

        /// 更新 Canvas 矩形位置。
        ///
        /// 当矩形发生显著变化时，触发防抖帧同步。
        public func updateLiveCanvasRect(_ rect: CGRect, scale: CGFloat) {
            let newRect = rect.standardized
            let newScale = max(scale, 1)
            isLiveCanvasVisible = true
            guard abs(newRect.origin.x - liveCanvasRect.origin.x) > 0.5
                || abs(newRect.origin.y - liveCanvasRect.origin.y) > 0.5
                || abs(newRect.size.width - liveCanvasRect.size.width) > 0.5
                || abs(newRect.size.height - liveCanvasRect.size.height) > 0.5
                || abs(newScale - liveCanvasScale) > 0.01 else {
                return
            }

            liveCanvasRect = newRect
            liveCanvasScale = newScale

            liveFrameSyncTask?.cancel()
            liveFrameSyncTask = Task {
                try? await Task.sleep(nanoseconds: 16000000)
                guard !Task.isCancelled else { return }
                guard displayMode == .live, canSyncFrame else { return }

                await onSyncLiveFrameFromEngine?("live canvas frame changed")
                if needsShowWhenFrameAvailable {
                    needsShowWhenFrameAvailable = false
                    await syncLiveVisibility(
                        showReason: "live canvas frame changed",
                        hideReason: "live canvas frame changed but display conditions are not satisfied"
                    )
                }
            }
        }

        /// Compatibility alias for older editor integration code.
        public func updateCanvasRect(_ rect: CGRect, scale: CGFloat) {
            updateLiveCanvasRect(rect, scale: scale)
        }

        /// Canvas 帧不可用时调用。
        public func liveCanvasFrameUnavailable() {
            // A transient missing frame does not mean the canvas disappeared. Keep the
            // last valid frame so the live preview remains anchored until an explicit
            // lifecycle event hides it.
        }

        /// Compatibility alias for older editor integration code.
        public func canvasFrameUnavailable() {
            liveCanvasFrameUnavailable()
        }

        /// Canvas 消失时调用。
        public func liveCanvasDidDisappear() {
            isLiveCanvasVisible = false
            needsShowWhenFrameAvailable = false
            cancelPendingFrameSync()
            guard displayMode == .live else { return }
            Task {
                await syncLiveVisibility(
                    showReason: "live canvas disappeared but display conditions still allow showing",
                    hideReason: "live canvas disappeared"
                )
            }
        }

        /// Compatibility alias for older editor integration code.
        public func canvasDidDisappear() {
            liveCanvasDidDisappear()
        }

        /// Canvas 出现时调用。
        public func liveCanvasDidAppear() {
            isLiveCanvasVisible = true
            guard displayMode == .live else { return }
            Task {
                if canSyncFrame {
                    needsShowWhenFrameAvailable = false
                    await onSyncLiveFrameFromEngine?("live canvas appeared")
                    await syncLiveVisibility(
                        showReason: "live canvas appeared",
                        hideReason: "live canvas appeared but display conditions are not satisfied"
                    )
                } else {
                    needsShowWhenFrameAvailable = true
                }
            }
        }

        /// Compatibility alias for older editor integration code.
        public func canvasDidAppear() {
            liveCanvasDidAppear()
        }

        /// 应用失去焦点时调用。
        public func lumiWindowDidResignKey() {
            // Focus changes do not imply the preview canvas disappeared. The live window
            // stays bound to the canvas lifecycle instead.
        }

        /// 应用获得焦点时调用。
        public func lumiWindowDidBecomeKey() {
            guard displayMode == .live else { return }
            Task {
                await onSyncLiveFrameFromEngine?("Lumi window became key")
                await syncLiveVisibility(
                    showReason: "Lumi window became key",
                    hideReason: "Lumi window became key but display conditions are not satisfied"
                )
            }
        }

        /// 窗口最小化或关闭时调用。
        public func lumiWindowDidMiniaturizeOrClose() {
            isLiveCanvasVisible = false
            guard displayMode == .live else { return }
            Task {
                await syncLiveVisibility(
                    showReason: "Lumi window minimized or closed but display conditions still allow showing",
                    hideReason: "Lumi window minimized or closed"
                )
            }
        }

        /// Owning app left the foreground; hide the host live window so it does not float
        /// above unrelated apps.
        public func appDidResignActive() {
            isAppActive = false
            cancelPendingFrameSync()
            guard displayMode == .live else { return }
            Task {
                await syncLiveVisibility(
                    showReason: "app resigned active but display conditions still allow showing",
                    hideReason: "app resigned active"
                )
            }
        }

        /// Owning app returned to foreground; resync frame and show if canvas is valid.
        public func appDidBecomeActive() {
            isAppActive = true
            guard displayMode == .live else { return }
            Task {
                if canSyncFrame {
                    await onSyncLiveFrameFromEngine?("app became active")
                }
                await syncLiveVisibility(
                    showReason: "app became active",
                    hideReason: "app became active but display conditions are not satisfied"
                )
            }
        }

        /// 预览所属编辑器窗口可见或恢复时调用。
        public func previewWindowDidBecomeActive() {
            guard displayMode == .live else { return }
            Task {
                if canSyncFrame {
                    await onSyncLiveFrameFromEngine?("preview window became active")
                }
                await syncLiveVisibility(
                    showReason: "preview window became active",
                    hideReason: "preview window became active but display conditions are not satisfied"
                )
            }
        }

        /// 预览所属编辑器窗口关闭、最小化或脱离窗口层级时调用。
        public func previewWindowDidBecomeInactive() {
            // Window focus/activity changes do not imply the preview canvas disappeared.
            // Visibility is driven by the canvas frame and explicit close/minimize hooks.
        }

        /// 取消所有挂起的帧同步任务。
        public func cancelPendingFrameSync() {
            liveFrameSyncTask?.cancel()
            liveFrameSyncTask = nil
        }

        /// 根据当前状态同步 Live 窗口显隐。
        public func syncLiveVisibility(showReason: String, hideReason: String) async {
            if shouldShowLiveWindow {
                await onShowLivePreview?(showReason)
            } else {
                await onHideLivePreview?(hideReason)
            }
        }
    }
}
