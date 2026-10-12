import Foundation

/// token 总数的紧凑展示格式。
///
/// 仪表盘会展示几十万到上亿量级的 token 总量，直接输出原始整数（如
/// `43982407`）无法一眼读出量级，因此统一压缩为「数字 + 单位」的写法。
///
/// 规则：
/// - 小于 1000 原样输出；
/// - 依次使用 K / M / B 单位，取「不超过量级」的最大单位；
/// - 单位值小于 100 时保留 1 位小数，否则取整；整数结果不补 `.0`；
/// - 四舍五入跨过 1000 时提升到更大单位（`999_999` → `"1M"`）。
enum TokenCountFormat {
    // MARK: - 常量/静态属性

    /// 按量级从大到小排列，`first(where:)` 即可取到不超过量级的最大单位。
    private static let units: [(divisor: Double, suffix: String)] = [
        (1_000_000_000, "B"),
        (1_000_000, "M"),
        (1_000, "K"),
    ]

    // MARK: - 公开方法

    /// 把 token 总数压缩为人类易读的紧凑写法。
    ///
    /// ```swift
    /// TokenCountFormat.compact(999)         // "999"
    /// TokenCountFormat.compact(43_982_407)  // "44M"
    /// ```
    static func compact(_ value: Int) -> String {
        guard value >= 1_000 else { return "\(value)" }

        let index = units.firstIndex { Double(value) >= $0.divisor } ?? units.count - 1
        let unit = units[index]

        // 取整后可能跨过量级（999_999 → 1000K），此时提升到更大单位。
        if index > 0, (Double(value) / unit.divisor).rounded() >= 1_000 {
            let larger = units[index - 1]
            return text(Double(value) / larger.divisor) + larger.suffix
        }
        return text(Double(value) / unit.divisor) + unit.suffix
    }

    // MARK: - 私有方法

    /// 单位值小于 100 保留 1 位小数，否则取整；整数结果不补 `.0`。
    private static func text(_ scaled: Double) -> String {
        guard scaled < 100 else { return String(Int(scaled.rounded())) }
        let rounded = (scaled * 10).rounded() / 10
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.1f", rounded)
    }
}
