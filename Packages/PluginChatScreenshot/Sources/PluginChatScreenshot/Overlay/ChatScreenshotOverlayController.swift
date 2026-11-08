import AppKit
import CoreGraphics
import Foundation

/// 多屏截图遮罩控制器
///
/// 负责:
/// - 为每个 `NSScreen` 创建一个 `ChatScreenshotOverlayWindow`
/// - 协调所有 view 的 drag 事件,合并为统一的全局 selectionRect
/// - 用户完成拖选后,call `onComplete(selection)`
/// - 用户 Esc 取消,call `onComplete(nil)`
@MainActor
final class ChatScreenshotOverlayController {

    private let onComplete: (CGRect?) -> Void
    private let screens: [NSScreen]
    private var windows: [ChatScreenshotOverlayWindow] = []
    private var views: [ChatScreenshotOverlayView] = []
    /// 全局选区(屏幕坐标,原点在左下)
    private var selectionRect: CGRect = .zero

    init(
        image: CGImage,
        captureFrame: CGRect,
        onComplete: @escaping (CGRect?) -> Void
    ) {
        self.onComplete = onComplete
        // 缓存参数(此处 image / captureFrame 由调用方持有,不需本类存)
        _ = image
        _ = captureFrame
        self.screens = NSScreen.screens
    }

    /// 给遮罩视图装配回调。
    ///
    /// 闭包一律弱捕获 `self` 与 `view`：视图强持有闭包，若闭包再强捕获视图，
    /// 就形成 `view → closure → view` 的引用环，`finish()` 清空数组后视图仍无法释放。
    ///
    /// 可见性放宽到 internal 仅为便于单元测试验证回调不构成引用环。
    internal func wireCallbacks(on view: ChatScreenshotOverlayView) {
        view.onSelectionChanged = { [weak self, weak view] rect in
            guard let self, let view else { return }
            self.handleSelectionChanged(view: view, rect: rect)
        }
        view.onSelectionCompleted = { [weak self] rect in
            self?.finish(selection: rect)
        }
        view.onCancel = { [weak self] in
            self?.finish(selection: nil)
        }
    }

    func show() {
        guard !screens.isEmpty else {
            onComplete(nil)
            return
        }

        for screen in screens {
            let view = ChatScreenshotOverlayView(screenFrame: screen.frame)
            wireCallbacks(on: view)

            let window = ChatScreenshotOverlayWindow(screenFrame: screen.frame, view: view)
            windows.append(window)
            views.append(view)
        }

        // 推到屏幕前
        for window in windows {
            window.orderFront(nil)
        }
        if let first = windows.first {
            first.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func cancel() {
        finish(selection: nil)
    }

    // MARK: - 私有

    /// 可见性放宽到 internal 仅为便于单元测试覆盖多屏选区同步逻辑。
    internal func handleSelectionChanged(view: ChatScreenshotOverlayView, rect: CGRect) {
        // 合并所有屏幕的局部 selection 为全局 selectionRect
        // 这里简单用最后触发事件的 view 的 selection 作为全局 rect;
        // 跨屏拖选场景极少,够用。
        selectionRect = rect
        for v in views where v !== view {
            v.selectionRect = rect
            v.needsDisplay = true
        }
    }

    private func finish(selection: CGRect?) {
        // 先 close 所有窗口,再回调(避免回调里再触发收尾)
        let callback = onComplete
        let rect = selection
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        views.removeAll()
        // 异步触发回调,避免在 NSWindow 事件循环中修改外部状态
        Task { @MainActor in
            callback(rect)
        }
    }
}
