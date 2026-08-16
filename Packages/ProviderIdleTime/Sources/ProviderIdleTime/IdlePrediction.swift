import Foundation

/// 对「请求的区间落在推断休息窗口内」的预测结果。
///
/// 由旧版 `KernelLumi/Types/Idle/IdlePrediction.swift` 迁移而来。
public struct IdlePrediction: Codable, Sendable, Equatable {
    public let checkedAt: Date
    public let duration: TimeInterval
    public let isLikelyIdle: Bool
    public let confidence: Double
    public let restWindow: RestWindow?

    public init(
        checkedAt: Date,
        duration: TimeInterval,
        isLikelyIdle: Bool,
        confidence: Double,
        restWindow: RestWindow?
    ) {
        self.checkedAt = checkedAt
        self.duration = duration
        self.isLikelyIdle = isLikelyIdle
        self.confidence = confidence
        self.restWindow = restWindow
    }
}
