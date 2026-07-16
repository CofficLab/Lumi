import Foundation
import EditorKernel
import os
import SuperLogKit

/// 自动保存防抖调度器。
///
/// 仅处理 `afterDelay` 模式的防抖触发；`onFocusChange` / `onWindowChange`
/// 模式由各自的生命周期事件直接调用 `EditorState.saveNowIfNeeded(reason:)`，
/// 不经过这里。
///
/// 设计要点：
/// - 所有调度都在 `@MainActor` 上进行，与 `EditorState` 一致。
/// - 复用 `EditorState.saveNowIfNeeded(reason:)`，自动享受已有的守卫
///   （`hasUnsavedChanges`、重入保护、外部冲突检测）。
/// - 自动保存路径跳过需要弹窗确认的文件（如 project.pbxproj）。
@MainActor
final class EditorAutoSaveScheduler: SuperLog {
    nonisolated static let verbose = EditorState.verbose
    private let logger = Logger(subsystem: EditorHostEnvironment.current.logSubsystem, category: "editor.auto-save")

    /// 当前的防抖 Task
    private var pendingTask: Task<Void, Never>?

    /// 当前绑定的编辑器状态（弱引用，避免循环）
    private weak var state: EditorState?

    /// 是否自动保存路径下应跳过该文件的保护计算缓存（避免重复计算）
    private var lastSkippedReason: String?

    init() {}

    /// 绑定编辑器状态（由 EditorState 在初始化后调用）
    func bind(state: EditorState) {
        self.state = state
    }

    /// 处理自动保存模式变化。
    func handleModeChange(_ mode: EditorAutoSaveMode) {
        if mode != .afterDelay {
            cancel()
        }
    }

    /// 处理延迟变化（不影响已排队的任务；下次调度使用新值）。
    func handleDelayChange(_ delay: Double) {
        // 无需立即处理；新调度会读取最新 delay
    }

    /// 内容变化时调度自动保存。
    /// 仅当当前模式为 `afterDelay` 且文件可安全自动保存时才调度。
    func scheduleIfNeeded() {
        guard let state else { return }

        // 仅 afterDelay 模式在此调度
        guard state.autoSaveMode == .afterDelay else {
            return
        }

        // 取消旧任务（防抖）
        cancel()

        let delay = clampedDelay(state.autoSaveDelay)
        pendingTask = Task { @MainActor [weak self, weak state] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            guard let self, let state else { return }
            // 再次确认模式未在等待期间被关闭
            guard state.autoSaveMode == .afterDelay else { return }
            state.triggerAutoSave(reason: "auto_save_after_delay")
        }
    }

    /// 取消待执行的自动保存。
    func cancel() {
        pendingTask?.cancel()
        pendingTask = nil
    }

    /// 限制延迟在合理区间 [0.1s, 10s]。
    private func clampedDelay(_ delay: Double) -> Double {
        min(max(delay, 0.1), 10.0)
    }
}
