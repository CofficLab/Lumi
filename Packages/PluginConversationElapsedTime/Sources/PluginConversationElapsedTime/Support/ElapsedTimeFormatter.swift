import Foundation

/// 时长的紧凑展示格式。
///
/// 规则：
/// - 不到 1 分钟显示秒（`45s`）；
/// - 不到 1 小时显示分钟（`23m`）；
/// - 1 小时以上显示小时，10 小时以内保留 1 位小数（`1.2h`），更大则取整（`26h`）。
enum ElapsedTimeFormatter {
    /// 把秒数压成人类易读的紧凑写法。
    ///
    /// ```swift
    /// ElapsedTimeFormatter.compact(45)      // "45s"
    /// ElapsedTimeFormatter.compact(1_380)    // "23m"
    /// ElapsedTimeFormatter.compact(4_320)   // "1.2h"
    /// ```
    static func compact(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        if total < 60 { return "\(total)s" }
        if total < 3_600 { return "\(Int((Double(total) / 60).rounded()))m" }

        let hours = Double(total) / 3_600
        if hours < 10 {
            let tenths = (hours * 10).rounded() / 10
            // 1.0h 读起来比 1h 啰嗦。
            if tenths == tenths.rounded() { return "\(Int(tenths))h" }
            return String(format: "%.1fh", tenths)
        }
        return "\(Int(hours.rounded()))h"
    }
}
