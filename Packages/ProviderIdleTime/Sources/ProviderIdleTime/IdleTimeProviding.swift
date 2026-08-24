import Foundation

/// 开发者活动追踪与休息窗口推断能力契约。
///
/// 由旧版 `KernelLumi/Providers/IdleTimeProviding.swift` 迁移而来，
/// 实现方（迁移后的 `IdleTimeService`）负责事件记录、休息窗口推断、
/// 快照缓存与预测；消费方应解析本 Provider，而非依赖具体插件。
public protocol IdleTimeProviding: AnyObject, Sendable {
    /// 记录一次开发者活动事件（带类型与时间）。
    func record(_ kind: IdleActivityKind, at date: Date) async

    /// 获取当前推断快照（休息窗口 + 统计信息）。
    func currentSnapshot(for date: Date) async -> IdleInferenceSnapshot

    /// 预测「从 date 起持续 duration 的区间」是否落在休息窗口内。
    func idlePrediction(for duration: TimeInterval, at date: Date) async -> IdlePrediction
}

public extension IdleTimeProviding {
    static var defaultIdlePredictionDuration: TimeInterval { 10 * 60 }

    /// 记录一次当前时刻的活动事件。
    func record(_ kind: IdleActivityKind) async {
        await record(kind, at: Date())
    }

    /// 获取当前时刻的推断快照。
    func currentSnapshot() async -> IdleInferenceSnapshot {
        await currentSnapshot(for: Date())
    }

    /// 预测默认时长（10 分钟）的休息窗口命中。
    func idlePrediction(
        for duration: TimeInterval = Self.defaultIdlePredictionDuration
    ) async -> IdlePrediction {
        await idlePrediction(for: duration, at: Date())
    }
}

/// 轻量内存实现：仅记录最近活动时间，不进行持久化与推断。
///
/// 用于宿主在真实 `IdleTimeService` 迁移完成前的占位；
/// 迁移后由 FactoryLumi 的 ProviderFactory 替换为完整实现。
public final actor DefaultIdleTimeProviding: IdleTimeProviding {
    private var lastActivityAt: Date?

    public init() {}

    public func record(_ kind: IdleActivityKind, at date: Date = Date()) async {
        lastActivityAt = date
    }

    public func currentSnapshot(for date: Date = Date()) async -> IdleInferenceSnapshot {
        IdleInferenceSnapshot(
            restWindow: nil,
            observedDayCount: 0,
            eventCount: 0,
            lastActivityAt: lastActivityAt,
            bucketScores: [],
            confidenceBreakdown: .zero
        )
    }

    public func idlePrediction(
        for duration: TimeInterval,
        at date: Date = Date()
    ) async -> IdlePrediction {
        IdlePrediction(
            checkedAt: date,
            duration: duration,
            isLikelyIdle: false,
            confidence: 0,
            restWindow: nil
        )
    }
}
