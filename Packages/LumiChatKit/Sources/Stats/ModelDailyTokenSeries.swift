import Foundation

/// 单个模型在某一天的 token 用量。
public struct ModelDailyTokenBucket: Sendable, Equatable {
    /// 已用 `startOfDay` 归一化的日期。
    public let day: Date
    public let inputTokens: Int
    public let outputTokens: Int

    public init(day: Date, inputTokens: Int, outputTokens: Int) {
        self.day = day
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }

    public var totalTokens: Int { inputTokens + outputTokens }
}

/// 单个模型在一段窗口期内的按天 token 序列。
///
/// `buckets` 保证连续: 窗口内无数据的天也会以零值占位,
/// 这样柱状图才不会因为缺天而错位。
public struct ModelDailyTokenSeries: Sendable, Equatable {
    public let providerID: String
    public let modelName: String
    /// 从窗口最早天到今天, 连续无缺刻(无数据的天为零桶)。
    public let buckets: [ModelDailyTokenBucket]

    public init(providerID: String, modelName: String, buckets: [ModelDailyTokenBucket]) {
        self.providerID = providerID
        self.modelName = modelName
        self.buckets = buckets
    }

    public var totalTokens: Int { buckets.reduce(0) { $0 + $1.totalTokens } }
    public var peakTokens: Int { buckets.map(\.totalTokens).max() ?? 0 }
    public var hasData: Bool { totalTokens > 0 }
}
