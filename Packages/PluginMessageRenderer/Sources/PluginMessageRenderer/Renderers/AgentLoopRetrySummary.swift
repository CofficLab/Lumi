import Foundation

/// 自动重试时间线标记的文案投影。
///
/// 抽成纯函数便于单测：重试次数与退避秒数都是运行时拼接的，
/// 若直接写死中文，英文界面会继续显示中文（#895）。
enum AgentLoopRetrySummary {
    static func statusText(
        attempt: Int?,
        maxAttempts: Int?,
        resolve: (String) -> String = { pluginLocalization.string($0) }
    ) -> String {
        guard let attempt, let maxAttempts else {
            return resolve("Retrying")
        }
        return String(format: resolve("Retrying (%lld/%lld)"), attempt, maxAttempts)
    }

    static func retryAfterText(
        seconds: String?,
        resolve: (String) -> String = { pluginLocalization.string($0) }
    ) -> String? {
        guard let seconds, let value = Int(seconds) else { return nil }
        return String(format: resolve("%lld seconds before retry"), value)
    }
}
