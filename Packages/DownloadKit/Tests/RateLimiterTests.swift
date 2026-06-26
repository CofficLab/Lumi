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
        // 限制为 100KB/s
        let limitBytesPerSecond = 100 * 1024
        let limiter = RateLimiter(bytesPerSecond: limitBytesPerSecond)
        
        // 申请 200KB 应该至少需要 2 秒
        let bytesToAcquire = 200 * 1024
        let start = ContinuousClock.now
        try await limiter.acquire(bytes: bytesToAcquire)
        let elapsed = ContinuousClock.now - start
        let elapsedSeconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        
        // 允许一定误差，但至少应该接近 2 秒
        #expect(
            elapsedSeconds >= 1.5,
            "200KB 在 100KB/s 限制下应至少耗时 1.5 秒，实际：\(elapsedSeconds)秒"
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
}
