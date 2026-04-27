import Foundation

// MARK: - LSP Request Pipeline
//
// Phase 6: 统一语言特性请求管线。
//
// 所有 LSP 异步功能（completion、hover、diagnostics、code actions、
// semantic tokens、inlay hints）共享同一请求生命周期模型：
//
//   1. 分配 request generation ID
//   2. 发起异步请求
//   3. 等待响应时，新请求可能到来并递增 generation
//   4. 响应到达时检查 generation 是否匹配
//   5. 如果不匹配（stale），丢弃结果
//   6. 如果匹配，应用结果并通知 UI

/// 请求代际跟踪器。
///
/// 每次发起新的 LSP 请求时递增 generation。
/// 响应到达时，如果其 generation 不等于当前 generation，
/// 说明该响应已过期（用户已触发新的请求），应被丢弃。
///
/// 这是 VS Code 风格 LSP 管线的基础设施。
final class RequestGeneration: @unchecked Sendable {
    private let lock = NSLock()
    private var _generation: UInt64 = 0

    /// 当前请求代际。
    var generation: UInt64 {
        lock.lock(); defer { lock.unlock() }
        return _generation
    }

    /// 递增并返回新的代际值。
    @discardableResult
    func next() -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        _generation += 1
        return _generation
    }

    /// 检查给定代际值是否仍然有效。
    func isCurrent(_ gen: UInt64) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return gen == _generation
    }

    /// 重置代际（例如文件切换时）。
    func reset() {
        lock.lock(); defer { lock.unlock() }
        _generation = 0
    }
}

/// 异步请求取消令牌。
///
/// 用于在发起 LSP 请求后，在响应到达前取消它。
/// 典型的用法场景：
/// - 用户在补全列表中快速输入，旧的补全请求应被取消
/// - 光标快速移动，旧的 hover 请求应被取消
final class CancellationContext: @unchecked Sendable {
    private let lock = NSLock()
    private var _isCancelled: Bool = false

    var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return _isCancelled
    }

    func cancel() {
        lock.lock(); defer { lock.unlock() }
        _isCancelled = true
    }

    func checkCancellation() throws {
        lock.lock(); defer { lock.unlock() }
        if _isCancelled {
            throw CancellationError()
        }
    }
}

/// LSP 请求生命周期包装器。
///
/// 结合了代际跟踪和取消支持。
/// 所有 LSP 管线（completion、hover、diagnostics 等）都应使用此包装器
/// 来确保不会应用过期结果。
final class LSPRequestLifecycle: @unchecked Sendable {
    private let lock = NSLock()
    private var _generation: UInt64 = 0
    private var _apply: (@Sendable (Any) -> Void)?

    /// 发起一个新的异步 LSP 请求。
    ///
    /// - Parameters:
    ///   - operation: 异步请求操作
    ///   - apply: 在主线程上执行，如果请求仍然有效（generation 匹配），应用结果
    ///
    /// 流程：
    /// 1. 递增 generation
    /// 2. 执行异步操作
    /// 3. 响应到达时检查 generation
    /// 4. 如果匹配，在主线程调用 apply
    func run<T: Sendable>(
        operation: @Sendable @escaping () async throws -> T,
        apply: @MainActor @escaping (T) -> Void
    ) {
        let gen: UInt64
        lock.lock()
        _generation += 1
        gen = _generation
        lock.unlock()

        Task {
            do {
                let result = try await operation()
                await MainActor.run {
                    let isCurrent: Bool
                    self.lock.lock()
                    isCurrent = (gen == self._generation)
                    self.lock.unlock()
                    guard isCurrent else { return }
                    apply(result)
                }
            } catch {
                // 请求被取消或其他错误，静默忽略
            }
        }
    }

    /// 重置所有状态（文件切换时调用）。
    func reset() {
        lock.lock(); defer { lock.unlock() }
        _generation = 0
    }
}
