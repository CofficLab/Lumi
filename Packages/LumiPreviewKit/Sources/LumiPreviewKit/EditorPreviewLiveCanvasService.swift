import AppKit
import Foundation

/// 编辑器预览 Live Canvas 可见性与帧同步服务。
///
/// 管理 Live 预览窗口的显示/隐藏状态逻辑，包括：
/// - 应用活跃状态跟踪
/// - 预览窗口活跃状态跟踪
/// - Canvas 可见性和帧矩形跟踪
/// - 根据综合条件决定是否显示/隐藏 Live 窗口
@MainActor
public final class EditorPreviewLiveCanvasService {

    /// 应用是否处于活跃状态（前台）。
    public private(set) var isApplicationActive: Bool

    /// 预览所属编辑器窗口是否仍可显示 Live overlay。
    ///
    /// 这里不能直接等同于 key window。Live overlay 自己可能短暂成为 key window
    /// 以支持 TextField、List 等真实控件交互，此时所属编辑器窗口会 resign key，
    /// 但 overlay 仍然应该保留。
    public private(set) var isPreviewWindowActive: Bool = true

    /// Canvas 是否可见。
    public private(set) var isLiveCanvasVisible: Bool = false

    /// Canvas 在屏幕坐标系中的矩形。
    public private(set) var liveCanvasRect: CGRect = .zero

    /// Canvas 所在屏幕 scale factor。
    public private(set) var liveCanvasScale: CGFloat = 1

    /// 当前显示模式。
    public private(set) var displayMode: PreviewDisplayMode

    /// 帧同步防抖 Task。
    private var liveFrameSyncTask: Task<Void, Never>?

    /// 触发 Live 预览帧同步的回调。
    public var onSyncLiveFrameFromEngine: (@MainActor () async -> Void)?

    /// 触发 Live 窗口显示的回调。
    public var onShowLivePreview: (@MainActor () async -> Void)?

    /// 触发 Live 窗口隐藏的回调。
    public var onHideLivePreview: (@MainActor () async -> Void)?

    public init(displayMode: PreviewDisplayMode) {
        self.displayMode = displayMode
        self.isApplicationActive = Self.sharedApplicationIfAvailable?.isActive ?? true
    }

    /// 是否具备显示 Live 窗口的全部条件。
    public var shouldShowLiveWindow: Bool {
        displayMode == .live
            && isApplicationActive
            && isPreviewWindowActive
            && isLiveCanvasVisible
            && !liveCanvasRect.isEmpty
    }

    /// 更新显示模式。
    public func updateDisplayMode(_ mode: PreviewDisplayMode) {
        displayMode = mode
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
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard !Task.isCancelled else { return }
            await onSyncLiveFrameFromEngine?()
        }
    }

    /// Canvas 帧不可用时调用。
    public func liveCanvasFrameUnavailable() {
        liveCanvasRect = .zero
        isLiveCanvasVisible = false
        guard displayMode == .live else { return }
        Task {
            await syncLiveVisibility()
        }
    }

    /// Canvas 消失时调用。
    public func liveCanvasDidDisappear() {
        isLiveCanvasVisible = false
        guard displayMode == .live else { return }
        Task {
            await syncLiveVisibility()
        }
    }

    /// Canvas 出现时调用。
    public func liveCanvasDidAppear() {
        isLiveCanvasVisible = true
        guard displayMode == .live else { return }
        Task {
            await onSyncLiveFrameFromEngine?()
            await syncLiveVisibility()
        }
    }

    /// 应用失去焦点时调用。
    public func lumiWindowDidResignKey() {
        isApplicationActive = false
        guard displayMode == .live else { return }
        Task {
            await syncLiveVisibility()
        }
    }

    /// 应用获得焦点时调用。
    public func lumiWindowDidBecomeKey() {
        isApplicationActive = true
        guard displayMode == .live else { return }
        Task {
            await onSyncLiveFrameFromEngine?()
            await syncLiveVisibility()
        }
    }

    /// 窗口最小化或关闭时调用。
    public func lumiWindowDidMiniaturizeOrClose() {
        isLiveCanvasVisible = false
        guard displayMode == .live else { return }
        Task {
            await syncLiveVisibility()
        }
    }

    /// 预览所属编辑器窗口可见或恢复时调用。
    public func previewWindowDidBecomeActive() {
        isPreviewWindowActive = true
        guard displayMode == .live else { return }
        Task {
            await onSyncLiveFrameFromEngine?()
            await syncLiveVisibility()
        }
    }

    /// 预览所属编辑器窗口关闭、最小化或脱离窗口层级时调用。
    public func previewWindowDidBecomeInactive() {
        isPreviewWindowActive = false
        guard displayMode == .live else { return }
        Task {
            await syncLiveVisibility()
        }
    }

    /// 取消所有挂起的帧同步任务。
    public func cancelPendingFrameSync() {
        liveFrameSyncTask?.cancel()
        liveFrameSyncTask = nil
    }

    private func syncLiveVisibility() async {
        if shouldShowLiveWindow {
            await onShowLivePreview?()
        } else {
            await onHideLivePreview?()
        }
    }

    private static var sharedApplicationIfAvailable: NSApplication? {
        NSClassFromString("NSApplication").flatMap { _ in NSApp }
    }
}
