import Foundation
import Testing

@testable import DownloadKit

@Suite("RateLimiter Tests")
struct RateLimiterTests {
    
    @Test("不限速时立即返回")
    func unlimitedRateLimiterReturnsImmediately() async throws {
        let limiter = RateLimiter(bytesPerSecond: nil)
        
        let start = ContinuousClock.now
        try await limiter.acquire(bytes: 1000)
        let elapsed = (ContinuousClock.now - start).components.seconds
        
        #expect(elapsed == 0, "不限速时应立即返回")
    }
    
    @Test("静态不限速实例")
    func staticUnlimitedInstance() async throws {
        let start = ContinuousClock.now
        try await RateLimiter.unlimited.acquire(bytes: 1_000_000)
        let elapsed = (ContinuousClock.now - start).components.seconds
        
        #expect(elapsed == 0, "静态不限速实例应立即返回")
    }
    
    @Test("限速器正确限制速率")
    func rateLimiterEnforcesSpeedLimit() async throws {
        // 限制为 100KB/s，桶容量 = max(1 秒的量, 请求量)
        let limitBytesPerSecond = 100 * 1024
        let limiter = RateLimiter(bytesPerSecond: limitBytesPerSecond)
        
        // 初始令牌 = 1 秒的量（100KB），可立即扣减；剩余 100KB 需按 100KB/s 等待 1 秒。
        // 因此 200KB 在 100KB/s 限制下约耗时 1 秒（含 1 秒突发额度）。
        let bytesToAcquire = 200 * 1024
        let start = ContinuousClock.now
        try await limiter.acquire(bytes: bytesToAcquire)
        let elapsed = ContinuousClock.now - start
        let elapsedSeconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        
        // 至少耗时约 1 秒（扣除初始 1 秒突发后，剩余 100KB 必须等待）；
        // 上界留足容差，避免调度抖动导致的偶发失败。
        #expect(
            elapsedSeconds >= 0.8 && elapsedSeconds < 2.5,
            "200KB 在 100KB/s 限制下应约耗时 1 秒（含突发额度），实际：\(elapsedSeconds)秒"
        )
    }
    
    @Test("零字节申请立即返回")
    func zeroBytesReturnsImmediately() async throws {
        let limiter = RateLimiter(bytesPerSecond: 1000)
        
        let start = ContinuousClock.now
        try await limiter.acquire(bytes: 0)
        let elapsed = (ContinuousClock.now - start).components.seconds
        
        #expect(elapsed == 0, "零字节申请应立即返回")
    }
    
    @Test("负数字节申请立即返回")
    func negativeBytesReturnsImmediately() async throws {
        let limiter = RateLimiter(bytesPerSecond: 1000)
        
        let start = ContinuousClock.now
        try await limiter.acquire(bytes: -100)
        let elapsed = (ContinuousClock.now - start).components.seconds
        
        #expect(elapsed == 0, "负数字节申请应立即返回")
    }
    
    @Test("小量数据在令牌桶容量内立即返回")
    func smallAmountWithinBucketCapacity() async throws {
        // 限制为 1MB/s，桶容量也是 1MB
        let limiter = RateLimiter(bytesPerSecond: 1_000_000)
        
        // 申请 100KB（远小于桶容量）应该立即返回
        let start = ContinuousClock.now
        try await limiter.acquire(bytes: 100 * 1024)
        let elapsed = ContinuousClock.now - start
        let elapsedMs = Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
        
        #expect(
            elapsedMs < 100,
            "小量数据在桶容量内应立即返回（<100ms），实际：\(elapsedMs)ms"
        )
    }
    
    @Test("运行时改为不限速后立即放行")
    func updateToUnlimitedUnblocksWaitingAcquire() async throws {
        // 初始限制为 100KB/s，桶容量也 100KB
        let limiter = RateLimiter(bytesPerSecond: 100 * 1024)
        
        // 先用掉初始令牌（满桶 100KB），使后续申请必须等待
        try await limiter.acquire(bytes: 100 * 1024)
        
        // 在后台发起一个「需要等待」的申请：300KB 在 100KB/s 下需 ~3 秒
        let acquireTask = Task {
            let s = ContinuousClock.now
            try await limiter.acquire(bytes: 300 * 1024)
            return ContinuousClock.now - s
        }
        
        // 等待一小段时间确保上面的 acquire 已进入等待（sleep）状态
        try await Task.sleep(for: .milliseconds(200))
        
        // 运行时改为不限速 —— 等待中的 acquire 应在数百毫秒内放行，而非等满 3 秒
        limiter.update(bytesPerSecond: nil)
        
        let elapsed = try await acquireTask.value
        let elapsedMs = Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
        
        // 放行后总耗时远小于 3 秒（容差 800ms 覆盖调度抖动 + 200ms 的前置 sleep）
        #expect(
            elapsedMs < 800,
            "改为不限速后等待中的 acquire 应快速放行（<800ms），实际：\(elapsedMs)ms"
        )
    }
    
    @Test("运行时调低限速后按新值限速")
    func updateToLowerLimitEnforcesNewRate() async throws {
        // 初始不限速
        let limiter = RateLimiter(bytesPerSecond: nil)
        
        // 先确认不限速时立即可用
        try await limiter.acquire(bytes: 10)
        
        // 改为 100KB/s
        limiter.update(bytesPerSecond: 100 * 1024)
        
        // 改完后立即申请 200KB：新桶容量=100KB（满桶），需等待 1 秒补足剩余 100KB
        let start = ContinuousClock.now
        try await limiter.acquire(bytes: 200 * 1024)
        let elapsed = ContinuousClock.now - start
        let elapsedSeconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        
        #expect(
            elapsedSeconds >= 0.8,
            "调低限速后应按新值限速（200KB@100KB/s 约 1 秒），实际：\(elapsedSeconds)秒"
        )
        #expect(limiter.bytesPerSecond == 100 * 1024, "更新后限速值应可读")
    }
}
