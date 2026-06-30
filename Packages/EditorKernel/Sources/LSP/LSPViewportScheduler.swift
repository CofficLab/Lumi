import Foundation

// MARK: - LSP Viewport Scheduler
//
// 基于 viewport 的 LSP 请求调度。
//
// 核心思想：
// - 快速滚动时不发送任何 LSP 请求（debounce）
// - 滚动停止后才对可见区域发请求
// - 对不同类型的 LSP 功能使用独立的 debounce 时间
// - 高优先级请求可取消低优先级请求，确保资源用于最紧急的任务

/// LSP Viewport 调度器。
///
/// 管理 viewport 变化触发的异步 LSP 请求：
/// 快速滚动期间节流，滚动停止后调度可见区域请求。
///
/// 支持优先级调度：高优先级请求可自动取消低优先级请求，
/// 确保系统资源优先分配给最紧急的操作（如代码动作 > 诊断 > 内联提示）。
@MainActor
public final class LSPViewportScheduler {
    // MARK: - Types

    /// LSP 请求类型
    public enum Kind: CaseIterable, Hashable {
        case inlayHints
        case diagnostics
        case codeActions

        /// 获取请求类型的默认优先级
        public var defaultPriority: Priority {
            switch self {
            case .codeActions: return .high      // 代码动作最重要（用户右键菜单）
            case .diagnostics: return .medium    // 诊断信息次之
            case .inlayHints: return .low        // 内联提示最不紧急
            }
        }

        /// 获取请求类型的默认 debounce 延迟（毫秒）
        public var defaultDebounceMs: Int64 {
            switch self {
            case .inlayHints: return Self.inlayHintsDebounceMs
            case .diagnostics: return Self.diagnosticsDebounceMs
            case .codeActions: return Self.codeActionsDebounceMs
            }
        }
    }

    /// LSP 请求优先级
    public enum Priority: Int, Comparable, Sendable {
        case low = 0
        case medium = 1
        case high = 2

        public static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    // MARK: - Constants

    /// Inlay hints 的 debounce 延迟（毫秒）
    public static let inlayHintsDebounceMs: Int64 = 500

    /// 诊断（diagnostics）的 debounce 延迟（毫秒）
    public static let diagnosticsDebounceMs: Int64 = 300

    /// 代码动作（code actions）的 debounce 延迟（毫秒）
    public static let codeActionsDebounceMs: Int64 = 400

    // MARK: - State

    /// 当前活跃的任务
    private var inlayHintsTask: Task<Void, Never>?
    private var diagnosticsTask: Task<Void, Never>?
    private var codeActionsTask: Task<Void, Never>?

    /// 上次已知的 viewport 范围（用于判断是否变化足够大需要重新请求）
    private var lastVisibleStartLine: Int = 0
    private var lastVisibleEndLine: Int = 0

    public init() {}

    // MARK: - Cancel

    /// 取消所有挂起的请求。
    public func cancelAll() {
        inlayHintsTask?.cancel()
        inlayHintsTask = nil
        diagnosticsTask?.cancel()
        diagnosticsTask = nil
        codeActionsTask?.cancel()
        codeActionsTask = nil
    }

    /// 取消指定类型的请求。
    public func cancel(_ type: Kind) {
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

    /// 取消所有低于指定优先级的挂起请求。
    ///
    /// 当一个高优先级请求到来时，可调用此方法取消所有低优先级的挂起请求，
    /// 释放资源给更紧急的任务。
    ///
    /// - Parameter priority: 低于此优先级的请求将被取消
    public func cancelBelow(_ priority: Priority) {
        for kind in Kind.allCases {
            if kind.defaultPriority < priority {
                cancel(kind)
            }
        }
    }

    // MARK: - Schedule

    /// 调度 LSP 请求。
    ///
    /// 统一的调度入口，支持优先级和自定义 debounce。
    /// 高优先级请求会自动取消低于自身优先级的挂起请求。
    ///
    /// - Parameters:
    ///   - type: 请求类型
    ///   - priority: 请求优先级，默认使用该类型的默认优先级
    ///   - cancelLowerPriority: 是否取消低于此优先级的挂起请求，默认 true
    ///   - debounceMs: 自定义 debounce 时间，nil 表示使用默认值
    ///   - operation: 延迟后执行的操作
    public func schedule(
        _ type: Kind,
        priority: Priority? = nil,
        cancelLowerPriority: Bool = true,
        debounceMs: Int64? = nil,
        operation: @escaping () async -> Void
    ) {
        let effectivePriority = priority ?? type.defaultPriority
        let effectiveDebounce = debounceMs ?? type.defaultDebounceMs

        // 高优先级请求取消低优先级挂起请求
        if cancelLowerPriority {
            cancelBelow(effectivePriority)
        }

        switch type {
        case .inlayHints:
            inlayHintsTask?.cancel()
            inlayHintsTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(effectiveDebounce))
                guard !Task.isCancelled else { return }
                await operation()
                self?.inlayHintsTask = nil
            }
        case .diagnostics:
            diagnosticsTask?.cancel()
            diagnosticsTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(effectiveDebounce))
                guard !Task.isCancelled else { return }
                await operation()
                self?.diagnosticsTask = nil
            }
        case .codeActions:
            codeActionsTask?.cancel()
            codeActionsTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(effectiveDebounce))
                guard !Task.isCancelled else { return }
                await operation()
                self?.codeActionsTask = nil
            }
        }
    }

    /// 调度 inlay hints 请求。
    ///
    /// - Parameters:
    ///   - priority: 请求优先级，默认 `.low`
    ///   - debounceMs: 自定义 debounce 时间，默认使用 `LSPViewportScheduler.inlayHintsDebounceMs`
    ///   - operation: 延迟后执行的操作
    public func scheduleInlayHints(
        priority: Priority = .low,
        debounceMs: Int64 = LSPViewportScheduler.inlayHintsDebounceMs,
        operation: @escaping () async -> Void
    ) {
        schedule(.inlayHints, priority: priority, debounceMs: debounceMs, operation: operation)
    }

    /// 调度 diagnostics 请求。
    ///
    /// - Parameters:
    ///   - priority: 请求优先级，默认 `.medium`
    ///   - debounceMs: 自定义 debounce 时间，默认使用 `LSPViewportScheduler.diagnosticsDebounceMs`
    ///   - operation: 延迟后执行的操作
    public func scheduleDiagnostics(
        priority: Priority = .medium,
        debounceMs: Int64 = LSPViewportScheduler.diagnosticsDebounceMs,
        operation: @escaping () async -> Void
    ) {
        schedule(.diagnostics, priority: priority, debounceMs: debounceMs, operation: operation)
    }

    /// 调度 code actions 请求。
    ///
    /// - Parameters:
    ///   - priority: 请求优先级，默认 `.high`
    ///   - debounceMs: 自定义 debounce 时间，默认使用 `LSPViewportScheduler.codeActionsDebounceMs`
    ///   - operation: 延迟后执行的操作
    public func scheduleCodeActions(
        priority: Priority = .high,
        debounceMs: Int64 = LSPViewportScheduler.codeActionsDebounceMs,
        operation: @escaping () async -> Void
    ) {
        schedule(.codeActions, priority: priority, debounceMs: debounceMs, operation: operation)
    }

    // MARK: - Viewport Tracking

    /// 记录上次的 viewport 范围。
    public func recordViewport(startLine: Int, endLine: Int) {
        lastVisibleStartLine = startLine
        lastVisibleEndLine = endLine
    }

    /// viewport 是否有显著变化（超过阈值行数）。
    public func hasSignificantViewportChange(
        startLine: Int,
        endLine: Int,
        threshold: Int = 10
    ) -> Bool {
        abs(startLine - lastVisibleStartLine) >= threshold ||
        abs(endLine - lastVisibleEndLine) >= threshold
    }
}
