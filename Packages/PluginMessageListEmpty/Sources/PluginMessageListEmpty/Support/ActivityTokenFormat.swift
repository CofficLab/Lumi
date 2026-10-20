import Foundation

/// Token 数量的紧凑写法（`128K`）。
///
/// A local copy rather than reusing the activity-heatmap plugin's formatter:
/// that type lives in another plugin and plugins must not depend on each other
/// (see the kernel/plugin boundary rule).
///
/// - Note: 单独成文件而不是挂在某个 View 上，是因为这张卡上有两处都要用它：
///   顶部的锚点文案与曲线的无障碍描述。挂在 View 上会逼着其中一处去引用
///   另一处的类型，反而把「谁拥有这个格式化规则」搅浑。
enum ActivityTokenFormat {
    /// 短到一个数位就够读的量级（`1.2M`），超过之后小数位是噪声（`150K`）。
    nonisolated static func compact(_ value: Int) -> String {
        let thresholds: [(limit: Double, suffix: String)] = [
            (1_000_000_000, "B"),
            (1_000_000, "M"),
            (1_000, "K"),
        ]
        for (limit, suffix) in thresholds where Double(value) >= limit {
            let scaled = Double(value) / limit
            // One decimal below 100 keeps "1.2M" readable; above it the
            // decimal is noise, so it is dropped ("150K", not "150.0K").
            let digits = scaled < 100 ? 1 : 0
            return String(format: "%.\(digits)f%@", scaled, suffix)
        }
        return String(value)
    }
}
