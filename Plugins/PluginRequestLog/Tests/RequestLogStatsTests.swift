import Testing
@testable import PluginRequestLog

@Suite("RequestLogStats")
struct RequestLogStatsTests {

    @Test("默认初始化所有值为零")
    func testDefaultValues() {
        let stats = RequestLogStats()
        #expect(stats.totalRequests == 0)
        #expect(stats.successCount == 0)
        #expect(stats.failedCount == 0)
        #expect(stats.successRate == 0)
        #expect(stats.averageDuration == 0)
    }

    @Test("自定义初始化保留所有值")
    func testCustomInit() {
        let stats = RequestLogStats(
            totalRequests: 100,
            successCount: 80,
            failedCount: 20,
            successRate: 0.8,
            averageDuration: 2.5
        )
        #expect(stats.totalRequests == 100)
        #expect(stats.successCount == 80)
        #expect(stats.failedCount == 20)
        #expect(stats.successRate == 0.8)
        #expect(stats.averageDuration == 2.5)
    }

    @Test("Stats 是 Sendable")
    func testSendable() {
        let stats = RequestLogStats(totalRequests: 10)
        // 可以在 Sendable 上下文中使用
        let _: @Sendable () -> RequestLogStats = { stats }
        #expect(stats.totalRequests == 10)
    }
}
