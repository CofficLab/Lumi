import Foundation

/// 请求日志统计信息
public struct RequestLogStats: Sendable {
    public var totalRequests: Int = 0
    public var successCount: Int = 0
    public var failedCount: Int = 0
    public var successRate: Double = 0
    public var averageDuration: Double = 0

    public init(
        totalRequests: Int = 0,
        successCount: Int = 0,
        failedCount: Int = 0,
        successRate: Double = 0,
        averageDuration: Double = 0
    ) {
        self.totalRequests = totalRequests
        self.successCount = successCount
        self.failedCount = failedCount
        self.successRate = successRate
        self.averageDuration = averageDuration
    }
}
