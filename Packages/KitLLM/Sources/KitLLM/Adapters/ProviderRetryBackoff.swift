import Foundation

/// 供应商重试的本地退避计算。
///
/// ## 为什么用等抖动而不是全抖动
///
/// AWS 的退避建议包含两种随机化方式：
///
/// - **全抖动**（full jitter）：`sleep = random(0, cap)`；
/// - **等抖动**（equal jitter）：`sleep = cap/2 + random(0, cap/2)`。
///
/// 529 是**全局**过载信号：服务端此刻无法接纳任何请求，拥堵来自所有客户端
/// 的合力。全抖动可能退化为 0 延迟，等于在服务端明确说「现在过载」的瞬间
/// 再打一次注定失败的请求，白白消耗掉一次重试预算。等抖动保留 `cap/2` 的
/// 下界：既让不同客户端的重试节奏错开（避免惊群），又保证两次重试之间存在
/// 实质间隔。
///
/// ## 与 `Retry-After` 的关系
///
/// 本退避只用于服务端**没有**给出建议的场景。一旦响应带了 `Retry-After`，
/// 等待时长必须精确等于服务端给的值，不能再叠加抖动——那会让实际等待短于
/// 服务端要求，破坏它给出的静默窗口。
public enum ProviderRetryBackoff {
    /// 计算第 `attempt` 次失败后的等待时间（秒）。
    ///
    /// - Parameters:
    ///   - base: 基础退避时长（秒），实际等待上限为 `base * 2^(attempt-1)`。
    ///   - attempt: 已失败次数，从 `1` 开始。
    ///   - randomUnit: `[0, 1)` 区间的随机数，用于注入抖动。生产环境传
    ///     `Double.random(in: 0..<1)`；测试传固定值以获得确定性结果。
    /// - Returns: 等待秒数，落在 `[cap/2, cap)` 区间内。
    public static func delay(base: TimeInterval, attempt: Int, randomUnit: Double) -> TimeInterval {
        let cap = cap(base: base, attempt: attempt)
        guard cap > 0 else { return 0 }
        let unit = min(max(randomUnit, 0), 1)
        return cap / 2 + (cap / 2) * unit
    }

    /// 第 `attempt` 次失败对应的指数退避上限（秒）。
    ///
    /// - Parameters:
    ///   - base: 基础退避时长（秒）。
    ///   - attempt: 已失败次数，从 `1` 开始。
    public static func cap(base: TimeInterval, attempt: Int) -> TimeInterval {
        guard base > 0 else { return 0 }
        let exponent = Double(max(0, attempt - 1))
        return base * pow(2.0, exponent)
    }
}
