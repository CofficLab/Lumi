import Foundation

/// 一次 LLM 请求的本地计时结果。
public struct LLMStreamTiming: Sendable, Equatable {
    /// 从发起请求到收到完整响应的时长（毫秒）。
    public let latencyMs: Double
    /// 从发起请求到收到第一个有效输出增量的时长（毫秒）。
    public let timeToFirstTokenMs: Double?
    /// 从第一个有效输出增量到收到完整响应的时长（毫秒）。
    public let streamingDurationMs: Double?

    public init(
        latencyMs: Double,
        timeToFirstTokenMs: Double?,
        streamingDurationMs: Double?
    ) {
        self.latencyMs = latencyMs
        self.timeToFirstTokenMs = timeToFirstTokenMs
        self.streamingDurationMs = streamingDurationMs
    }
}

/// 流式请求计时器。
///
/// 计时发生在 AgentLoop 的通用流式边界，因此所有实现
/// `LLMStreamingProviding` 的供应商（包括阿里云 CodingPlan）都能获得同一套
/// 速度元数据。使用单调时钟，避免系统时间调整影响结果。
public final class LLMStreamTimingRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private let startedAt: UInt64
    private var firstOutputAt: UInt64?

    public init() {
        startedAt = DispatchTime.now().uptimeNanoseconds
    }

    /// 标记第一个有效输出增量；重复调用不会覆盖原始时间。
    public func markFirstOutput() {
        let now = DispatchTime.now().uptimeNanoseconds
        lock.lock()
        defer { lock.unlock() }
        if firstOutputAt == nil {
            firstOutputAt = now
        }
    }

    /// 结束计时并生成快照。
    public func finish() -> LLMStreamTiming {
        let endedAt = DispatchTime.now().uptimeNanoseconds
        lock.lock()
        let firstOutputAt = self.firstOutputAt
        lock.unlock()

        return LLMStreamTiming(
            latencyMs: Self.milliseconds(from: startedAt, to: endedAt),
            timeToFirstTokenMs: firstOutputAt.map {
                Self.milliseconds(from: startedAt, to: $0)
            },
            streamingDurationMs: firstOutputAt.map {
                Self.milliseconds(from: $0, to: endedAt)
            }
        )
    }

    private static func milliseconds(from start: UInt64, to end: UInt64) -> Double {
        guard end >= start else { return 0 }
        return Double(end - start) / 1_000_000
    }
}
