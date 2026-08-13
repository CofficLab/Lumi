import Foundation

/// 某一天的 token 消耗量（跨所有对话）。
///
/// 用于 token 用量图表。`day` 已按当前日历归一化到当天 00:00。
public struct MessageTokenUsage: Sendable, Equatable {
    /// 已用当前日历归一化到当天 00:00 的日期。
    public let day: Date
    public let inputTokens: Int
    public let outputTokens: Int

    public init(day: Date, inputTokens: Int, outputTokens: Int) {
        self.day = day
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }

    public var totalTokens: Int {
        inputTokens + outputTokens
    }
}
