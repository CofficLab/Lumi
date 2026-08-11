import AppKit
import EditorService
import Foundation

/// 主窗口的保存代理。
///
/// 负责在以下时机触发自动保存（遵循 `autoSaveMode` 语义）：
/// - `windowWillClose`：窗口关闭前保存（数据不丢失安全网）。
/// - `windowDidResignKey`：窗口失去焦点时保存（`onWindowChange` 模式）。
///
/// 该代理弱持有 `EditorService`，避免循环引用。每个窗口绑定独立的代理实例，
/// 因此多窗口场景下能正确区分各自的编辑器。
@MainActor
final class EditorWindowSaveDelegate: NSObject, NSWindowDelegate {
    private weak var editorService: EditorService?

    /// 原始 delegate，确保不破坏既有窗口行为（如 SwiftUI 内部可能设置的 delegate）。
    private weak var originalDelegate: NSWindowDelegate?

    init(editorService: EditorService) {
        self.editorService = editorService
        super.init()
    }

    func attach(to window: NSWindow) {
        originalDelegate = window.delegate
        window.delegate = self
    }

    func windowWillClose(_ notification: Notification) {
        // 关窗是数据安全网：无论模式如何，有未保存变更就保存。
        // 这里使用 saveNowIfNeeded 而非 triggerAutoSave，确保即使关闭了
        // 自动保存也不会丢失编辑成果。
        editorService?.files.saveNowIfNeeded(reason: "window_will_close")
        // 转发给原始 delegate
        originalDelegate?.windowWillClose?(notification)
    }

    func windowDidResignKey(_ notification: Notification) {
        // 仅 onWindowChange 模式响应窗口失焦
        guard let mode = editorService?.files.autoSaveMode,
              mode.respondsToWindowChange else {
            originalDelegate?.windowDidResignKey?(notification)
            return
        }
        editorService?.files.triggerAutoSave(reason: "window_lost_key")
        originalDelegate?.windowDidResignKey?(notification)
    }
}
