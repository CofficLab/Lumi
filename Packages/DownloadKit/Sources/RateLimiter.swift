import Foundation

/// 基于令牌桶算法的下载速率限制器
///
/// 令牌桶以恒定速率 `bytesPerSecond` 填充令牌，每次下载前通过 `acquire(bytes:)`
/// 申请指定数量的令牌。若令牌不足，方法会自动 `Task.sleep` 等待令牌累积。
///
/// 该实现保证：
/// - 长时间平均速率不超过 `bytesPerSecond`
/// - 突发下载最多允许 `bytesPerSecond` 字节的突发量（桶容量 = 1 秒的量）
/// - `bytesPerSecond` 为 `nil` 时表示不限速，`acquire` 立即返回
///
/// 限速值支持运行时动态调整：调用 `update(bytesPerSecond:)` 后，正在进行的 `acquire`
/// 会在下一次令牌补充时读取新值，无需重启下载任务。常用于「下载到一半改限速」场景。
///
/// 用法：
/// ```swift
/// let limiter = RateLimiter(bytesPerSecond: 512 * 1024) // 512 KB/s
/// for try await byte in bytes {
///     try await limiter.acquire(bytes: 1)
///     // ... write byte
/// }
/// // 运行时调整（如用户在设置里改了限速）
/// limiter.update(bytesPerSecond: 2 * 1024 * 1024) // 改为 2 MB/s
/// ```
public final class RateLimiter: Sendable {
    /// 速率限制值（字节/秒）。`nil` 表示不限速。
    ///
    /// 由内部锁保护，通过 `update(bytesPerSecond:)` 修改。读取始终走 `currentLimit()`
    /// 以保证一致快照，避免 `acquire` 在锁外读到部分写入的值。
    private nonisolated(unsafe) var _bytesPerSecond: Int?

    /// 不限速实例
    public static let unlimited = RateLimiter(bytesPerSecond: nil)

    public init(bytesPerSecond: Int?) {
        self._bytesPerSecond = bytesPerSecond
        self.availableTokens = Double(bytesPerSecond ?? 0) // 初始令牌数等于桶容量
        self.lastRefillTime = ContinuousClock.now
    }

    /// 当前限速值（字节/秒）。`nil` 表示不限速。
    ///
    /// 读取内部值的一致快照。对外公开便于日志/断言，不应用于限速判定逻辑
    ///（请使用 `update(bytesPerSecond:)` 修改）。
    public var bytesPerSecond: Int? {
        lock.withLock { _bytesPerSecond }
    }

    /// 动态更新限速值（字节/秒）。`nil` 表示不限速。
    ///
    /// 线程安全，可在下载进行中调用。更新后的值会在 `acquire` 下一次循环读取生效：
    /// - 从受限速改为不限速：等待中的 `acquire` 立即放行
    /// - 从不限速改为受限速：下一次 `acquire` 起按新值限速
    /// - 调整限速数值：重置可用令牌为新的桶容量（避免新旧速率混淆，保持突发上限一致）
    public func update(bytesPerSecond: Int?) {
        lock.withLock {
            _bytesPerSecond = bytesPerSecond
            // 令牌桶容量与速率绑定：新速率下桶容量 = 1 秒的量，令牌重置为满桶，
            // 避免旧速率残留的令牌在新速率下造成瞬时过冲。
            availableTokens = Double(bytesPerSecond ?? 0)
            lastRefillTime = ContinuousClock.now
        }
    }

    /// 申请指定数量的字节令牌。如果当前令牌不足，会异步等待直到令牌足够。
    ///
    /// 此方法是线程安全的（使用内部锁保护状态）。
    ///
    /// - Parameter bytes: 需要申请的字节数（必须 > 0）
    /// - Throws: 当任务被取消时抛出 `CancellationError`
    public func acquire(bytes: Int) async throws {
        guard bytes > 0 else { return } // 零/负字节立即返回

        try await _acquire(bytes: bytes)
    }

    // MARK: - Private

    /// 内部存储状态（非 Sendable，由锁保护）
    private nonisolated(unsafe) var availableTokens: Double
    private nonisolated(unsafe) var lastRefillTime: ContinuousClock.Instant
    private let lock = NSLock()

    private func _acquire(bytes: Int) async throws {
        while !Task.isCancelled {
            // 每轮循环重新读取 limit，使运行时 update() 生效：从不限速切到限速、
            // 或反之、或调整数值，都在下一轮立即按新值行为。
            let limit = bytesPerSecond
            guard let limit else {
                return // 当前不限速，立即放行
            }

            // 桶容量取「1 秒的量」与「本次请求量」的较大者：
            // - 常规请求（≤ 1 秒的量）允许 1 秒突发，与原设计一致；
            // - 单次大批量请求（如 64KB 缓冲在低速率下 > 1 秒的量）仍能被满足，
            //   否则令牌永远被上限卡在 < needed，acquire 死等。
            // 突发上限按「1 秒的量」宽松保留——长时间平均速率仍由 refillRate 严格约束。
            let neededDouble = Double(bytes)
            let bucketCapacity = max(Double(limit), neededDouble)
            let refillRate = Double(limit) // 每秒填充 limit 个令牌

            let waitDuration = lock.withLock { () -> Duration? in
                let now = ContinuousClock.now
                // 计算自上次补充以来新增的令牌数
                let elapsed = Double((now - lastRefillTime).components.attoseconds) / 1e18
                    + Double((now - lastRefillTime).components.seconds)

                // 补充令牌（不超过桶容量）
                let newTokens = elapsed * refillRate
                availableTokens = min(bucketCapacity, availableTokens + newTokens)
                lastRefillTime = now

                if availableTokens >= neededDouble {
                    // 令牌充足，直接扣除
                    availableTokens -= neededDouble
                    return nil
                } else {
                    // 令牌不足：只计算「到令牌足够还需多久」，不清零已积累的令牌。
                    // 清零会导致分片睡眠时令牌永远累积不到 needed（每片刚补一点又被清零），
                    // 从而死等。保留令牌使其持续累积，下一轮睡醒后继续在已有基础上补充。
                    let deficit = neededDouble - availableTokens
                    let waitSeconds = deficit / refillRate
                    return .seconds(waitSeconds)
                }
            }

            guard let waitDuration else {
                return // 令牌充足，完成本次申请
            }

            // 分片睡眠：单次最多睡 pollingInterval，睡醒后回到循环顶部重新读取 limit，
            // 使运行时 update()（如把限速改为不限速）能在 pollingInterval 内打断等待生效，
            // 而不必等满整个 waitDuration。令牌补充由下一轮按真实经过的时间计算，分片不影响精度。
            let pollingInterval: Duration = .milliseconds(100)
            let slice = min(waitDuration, pollingInterval)
            try await Task.sleep(for: slice)
        }

        throw CancellationError()
    }
}
