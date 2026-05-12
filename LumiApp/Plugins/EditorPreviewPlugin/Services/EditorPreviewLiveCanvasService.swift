#if canImport(LumiPreviewKit)
import AppKit
import Foundation
import LumiPreviewKit

/// 编辑器预览 Live Canvas 可见性与帧同步服务。
///
/// 管理 Live 预览窗口的显示/隐藏状态逻辑，包括：
/// - 应用活跃状态跟踪
/// - 预览窗口活跃状态跟踪
/// - Canvas 可见性和帧矩形跟踪
/// - 根据综合条件决定是否显示/隐藏 Live 窗口
@MainActor
final class EditorPreviewLiveCanvasService {

    // MARK: - 属性

    /// 应用是否处于活跃状态（前台）。
    private(set) var isApplicationActive: Bool = NSApp.isActive

    /// 预览窗口是否活跃。
    private(set) var isPreviewWindowActive: Bool = true

    /// Canvas 是否可见。
    private(set) var isLiveCanvasVisible: Bool = false

    /// Canvas 在屏幕坐标系中的矩形。
    private(set) var liveCanvasRect: CGRect = .zero

    /// 当前显示模式。
    private(set) var displayMode: PreviewDisplayMode

    /// 帧同步防抖 Task。
    private var liveFrameSyncTask: Task<Void, Never>?

    /// 触发 Live 预览帧同步的回调。
    var onSyncLiveFrameFromEngine: (@MainActor () async -> Void)?

    /// 触发 Live 窗口显示的回调。
    var onShowLivePreview: (@MainActor () async -> Void)?

    /// 触发 Live 窗口隐藏的回调。
    var onHideLivePreview: (@MainActor () async -> Void)?

    // MARK: - 初始化

    init(displayMode: PreviewDisplayMode) {
        self.displayMode = displayMode
    }

    // MARK: - 计算属性

    /// 是否具备显示 Live 窗口的全部条件。
    var shouldShowLiveWindow: Bool {
        displayMode == .live
            && isApplicationActive
            && isPreviewWindowActive
            && isLiveCanvasVisible
            && !liveCanvasRect.isEmpty
    }

    // MARK: - 公开方法

    /// 更新显示模式。
    func updateDisplayMode(_ mode: PreviewDisplayMode) {
        displayMode = mode
    }

    /// 更新 Canvas 矩形位置。
    ///
    /// 当矩形发生显著变化时，触发防抖帧同步。
    func updateLiveCanvasRect(_ rect: CGRect) {
        let newRect = rect.standardized
        isLiveCanvasVisible = true
        guard abs(newRect.origin.x - liveCanvasRect.origin.x) > 0.5
            || abs(newRect.origin.y - liveCanvasRect.origin.y) > 0.5
            || abs(newRect.size.width - liveCanvasRect.size.width) > 0.5
            || abs(newRect.size.height - liveCanvasRect.size.height) > 0.5 else {
            return
        }

        liveCanvasRect = newRect

        // 防抖帧同步
        liveFrameSyncTask?.cancel()
        liveFrameSyncTask = Task {
            try? await Task.sleep(nanoseconds: 16_000_000) // ~1 frame at 60fps
            guard !Task.isCancelled else { return }
            await onSyncLiveFrameFromEngine?()
        }
    }

    /// Canvas 帧不可用时调用。
    func liveCanvasFrameUnavailable() {
        liveCanvasRect = .zero
        isLiveCanvasVisible = false
        guard displayMode == .live else { return }
        Task {
            await syncLiveVisibility()
        }
    }

    /// Canvas 消失时调用。
    func liveCanvasDidDisappear() {
        isLiveCanvasVisible = false
        guard displayMode == .live else { return }
        Task {
            await syncLiveVisibility()
        }
    }

    /// Canvas 出现时调用。
    func liveCanvasDidAppear() {
        isLiveCanvasVisible = true
        guard displayMode == .live else { return }
        Task {
            await onSyncLiveFrameFromEngine?()
            await syncLiveVisibility()
        }
    }

    /// 应用失去焦点时调用。
    func lumiWindowDidResignKey() {
        isApplicationActive = false
        guard displayMode == .live else { return }
        Task {
            await syncLiveVisibility()
        }
    }

    /// 应用获得焦点时调用。
    func lumiWindowDidBecomeKey() {
        isApplicationActive = true
        guard displayMode == .live else { return }
        Task {
            await onSyncLiveFrameFromEngine?()
            await syncLiveVisibility()
        }
    }

    /// 窗口最小化或关闭时调用。
    func lumiWindowDidMiniaturizeOrClose() {
        isLiveCanvasVisible = false
        guard displayMode == .live else { return }
        Task {
            await syncLiveVisibility()
        }
    }

    /// 预览窗口变为活跃时调用。
    func previewWindowDidBecomeActive() {
        isPreviewWindowActive = true
        guard displayMode == .live else { return }
        Task {
            await onSyncLiveFrameFromEngine?()
            await syncLiveVisibility()
        }
    }

    /// 预览窗口变为非活跃时调用。
    func previewWindowDidBecomeInactive() {
        isPreviewWindowActive = false
        guard displayMode == .live else { return }
        Task {
            await syncLiveVisibility()
        }
    }

    /// 取消所有挂起的帧同步任务。
    func cancelPendingFrameSync() {
        liveFrameSyncTask?.cancel()
        liveFrameSyncTask = nil
    }

    // MARK: - 私有方法

    private func syncLiveVisibility() async {
        if shouldShowLiveWindow {
            await onShowLivePreview?()
        } else {
            await onHideLivePreview?()
        }
    }
}
#endif
