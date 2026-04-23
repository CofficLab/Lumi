import Foundation

/// LSP 请求防抖/节流器
///
/// 防止快速连续触发导致的大量后台请求。支持两种策略：
/// - **debounce**：延迟执行，新请求会取消旧请求（适合 hover、补全等）
/// - **throttle**：确保两次调用之间至少有指定间隔（适合滚动高亮、文档高亮等）
actor LSPDebouncer {

    // MARK: - 常量

    /// 默认防抖延迟（150ms）
    static let defaultDebounceDelay: UInt64 = 150_000_000
    /// 默认节流间隔（250ms）
    static let defaultThrottleInterval: UInt64 = 250_000_000

    // MARK: - 属性

    private var pendingDebounceTasks: [String: Task<Void, Never>] = [:]
    private var lastThrottleTimes: [String: UInt64] = [:]

    // MARK: - Debounce

    /// 执行防抖请求。同一 key 的新请求会取消旧请求，等待指定延迟后执行。
    func debounce<T: Sendable>(
        key: String,
        delay: UInt64? = nil,
        operation: @escaping @Sendable () async -> T?
    ) async -> T? {
        // 取消同 key 的旧任务
        pendingDebounceTasks[key]?.cancel()
        pendingDebounceTasks.removeValue(forKey: key)

        let delayNanoseconds = delay ?? Self.defaultDebounceDelay
        let task = Task<T?, Never> {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return nil }
            return await operation()
        }

        let tracker = Task<Void, Never> {
            _ = await task.value
            // 任务完成后清理
            self.pendingDebounceTasks.removeValue(forKey: key)
        }
        pendingDebounceTasks[key] = tracker

        return await task.value
    }

    // MARK: - Throttle

    /// 执行节流请求。确保同一 key 的两次调用之间至少有指定间隔。
    func throttle<T: Sendable>(
        key: String,
        interval: UInt64? = nil,
        operation: @escaping @Sendable () async -> T?
    ) async -> T? {
        let intervalNanoseconds = interval ?? Self.defaultThrottleInterval
        let now = DispatchTime.now().uptimeNanoseconds

        // 检查是否过了节流窗口
        if let lastTime = lastThrottleTimes[key],
           now - lastTime < intervalNanoseconds {
            return nil
        }

        lastThrottleTimes[key] = now
        return await operation()
    }

    // MARK: - 清理

    /// 取消指定 key 的待执行任务
    func cancel(key: String) {
        pendingDebounceTasks[key]?.cancel()
        pendingDebounceTasks.removeValue(forKey: key)
    }

    /// 取消所有待执行任务
    func cancelAll() {
        pendingDebounceTasks.values.forEach { $0.cancel() }
        pendingDebounceTasks.removeAll()
        lastThrottleTimes.removeAll()
    }
}
