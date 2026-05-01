import Foundation

// MARK: - LSP Viewport Scheduler
//
// Phase 8: 基于 viewport 的 LSP 请求调度。
//
// 核心思想：
// - 快速滚动时不发送任何 LSP 请求（debounce）
// - 滚动停止后才对可见区域发请求
// - 对不同类型的 LSP 功能使用独立的 debounce 时间

/// LSP Viewport 调度器。
///
/// 管理 viewport 变化触发的异步 LSP 请求：
/// 快速滚动期间节流，滚动停止后调度可见区域请求。
@MainActor
final class LSPViewportScheduler: ObservableObject {
    /// Inlay hints 的 debounce 延迟（毫秒）
    static let inlayHintsDebounceMs: Int64 = 500

    /// 诊断（diagnostics）的 debounce 延迟（毫秒）
    static let diagnosticsDebounceMs: Int64 = 300

    /// 代码动作（code actions）的 debounce 延迟（毫秒）
    static let codeActionsDebounceMs: Int64 = 400

    /// 当前活跃的任务
    private var inlayHintsTask: Task<Void, Never>?
    private var diagnosticsTask: Task<Void, Never>?
    private var codeActionsTask: Task<Void, Never>?

    /// 上次已知的 viewport 范围（用于判断是否变化足够大需要重新请求）
    private var lastVisibleStartLine: Int = 0
    private var lastVisibleEndLine: Int = 0

    /// 取消所有挂起的请求。
    func cancelAll() {
        inlayHintsTask?.cancel()
        inlayHintsTask = nil
        diagnosticsTask?.cancel()
        diagnosticsTask = nil
        codeActionsTask?.cancel()
        codeActionsTask = nil
    }

    /// 取消指定类型的请求。
    func cancel(_ type: Kind) {
        switch type {
        case .inlayHints:
            inlayHintsTask?.cancel()
            inlayHintsTask = nil
        case .diagnostics:
            diagnosticsTask?.cancel()
            diagnosticsTask = nil
        case .codeActions:
            codeActionsTask?.cancel()
            codeActionsTask = nil
        }
    }

    /// 调度 inlay hints 请求。
    ///
    /// - Parameters:
    ///   - debounceMs: 自定义 debounce 时间，默认使用 `LSPViewportScheduler.inlayHintsDebounceMs`
    ///   - operation: 延迟后执行的操作
    func scheduleInlayHints(
        debounceMs: Int64 = LSPViewportScheduler.inlayHintsDebounceMs,
        operation: @escaping () async -> Void
    ) {
        inlayHintsTask?.cancel()
        inlayHintsTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(debounceMs))
            guard !Task.isCancelled else { return }
            await operation()
            self?.inlayHintsTask = nil
        }
    }

    /// 调度 diagnostics 请求。
    func scheduleDiagnostics(
        debounceMs: Int64 = LSPViewportScheduler.diagnosticsDebounceMs,
        operation: @escaping () async -> Void
    ) {
        diagnosticsTask?.cancel()
        diagnosticsTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(debounceMs))
            guard !Task.isCancelled else { return }
            await operation()
            self?.diagnosticsTask = nil
        }
    }

    /// 调度 code actions 请求。
    func scheduleCodeActions(
        debounceMs: Int64 = LSPViewportScheduler.codeActionsDebounceMs,
        operation: @escaping () async -> Void
    ) {
        codeActionsTask?.cancel()
        codeActionsTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(debounceMs))
            guard !Task.isCancelled else { return }
            await operation()
            self?.codeActionsTask = nil
        }
    }

    /// 记录上次的 viewport 范围。
    func recordViewport(startLine: Int, endLine: Int) {
        lastVisibleStartLine = startLine
        lastVisibleEndLine = endLine
    }

    /// viewport 是否有显著变化（超过阈值行数）。
    func hasSignificantViewportChange(
        startLine: Int,
        endLine: Int,
        threshold: Int = 10
    ) -> Bool {
        abs(startLine - lastVisibleStartLine) >= threshold ||
        abs(endLine - lastVisibleEndLine) >= threshold
    }

    /// LSP 请求类型
    enum Kind {
        case inlayHints
        case diagnostics
        case codeActions
    }
}
