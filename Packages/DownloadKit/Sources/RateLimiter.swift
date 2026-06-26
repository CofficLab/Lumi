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
/// 用法：
/// ```swift
/// let limiter = RateLimiter(bytesPerSecond: 512 * 1024) // 512 KB/s
/// for try await byte in bytes {
///     try await limiter.acquire(bytes: 1)
///     // ... write byte
/// }
/// ```
public final class RateLimiter: Sendable {
    /// 速率限制值（字节/秒）。`nil` 表示不限速。
    public let bytesPerSecond: Int?

    /// 不限速实例
    public static let unlimited = RateLimiter(bytesPerSecond: nil)

    public init(bytesPerSecond: Int?) {
        self.bytesPerSecond = bytesPerSecond
        self.availableTokens = Double(bytesPerSecond ?? 0) // 初始令牌数等于桶容量
        self.lastRefillTime = ContinuousClock.now
    }

    /// 申请指定数量的字节令牌。如果当前令牌不足，会异步等待直到令牌足够。
    ///
    /// 此方法是线程安全的（使用内部锁保护状态）。
    ///
    /// - Parameter bytes: 需要申请的字节数（必须 > 0）
    /// - Throws: 当任务被取消时抛出 `CancellationError`
    public func acquire(bytes: Int) async throws {
        guard let limit = bytesPerSecond, bytes > 0 else {
            return // 不限速
        }

        try await _acquire(bytes: bytes, limit: limit)
    }

    // MARK: - Private

    /// 内部存储状态（非 Sendable，由锁保护）
    private nonisolated(unsafe) var availableTokens: Double
    private nonisolated(unsafe) var lastRefillTime: ContinuousClock.Instant
    private let lock = NSLock()

    private func _acquire(bytes: Int, limit: Int) async throws {
        // 桶容量设为 1 秒的量，允许短暂突发但不超过 1 秒的额度
        let bucketCapacity = Double(limit)
        let refillRate = Double(limit) // 每秒填充 limit 个令牌

        while !Task.isCancelled {
            let (_, waitDuration) = lock.withLock { () -> (Double, Duration?) in
                let now = ContinuousClock.now
                // 计算自上次补充以来新增的令牌数
                let elapsed = Double((now - lastRefillTime).components.attoseconds) / 1e18
                    + Double((now - lastRefillTime).components.seconds)

                // 补充令牌（不超过桶容量）
                let newTokens = elapsed * refillRate
                availableTokens = min(bucketCapacity, availableTokens + newTokens)
                lastRefillTime = now

                let needed = Double(bytes)
                if availableTokens >= needed {
                    // 令牌充足，直接扣除
                    availableTokens -= needed
                    return (needed, nil)
                } else {
                    // 令牌不足，计算需要等待的时间
                    let deficit = needed - availableTokens
                    let waitSeconds = deficit / refillRate
                    // 消耗所有当前令牌
                    availableTokens = 0
                    return (needed, .seconds(waitSeconds))
                }
            }

            if let waitDuration {
                try await Task.sleep(for: waitDuration)
            } else {
                return
            }
        }

        throw CancellationError()
    }
}
