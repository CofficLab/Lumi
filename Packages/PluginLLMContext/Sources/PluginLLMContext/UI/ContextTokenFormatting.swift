import Foundation

extension Int {
    /// 格式化 token 数量为简短显示：1000 → "1K"，1500 → "2K"。
    var formattedTokensShort: String {
        let k = self > 0
            ? self / 1000 + (self % 1000 == 0 ? 0 : 1)
            : (self + 999) / 1000
        return "\(k)K"
    }

    /// 格式化上下文大小为简短显示：128000 → "128K"，1000000 → "1M"。
    var formattedContextSize: String {
        if self >= 1_000_000 {
            let m = Double(self) / 1_000_000
            if m == m.rounded() { return "\(Int(m))M" }
            return String(format: "%.1fM", m)
        }
        // 不足 1K 时整数除法会把 1...999 全部压成「0K」，不同的真实用量
        // 在趋势标签和 Min/Max 里无法区分；直接显示实际 token 数。
        if self < 1_000 { return "\(self)" }
        return "\(self / 1000)K"
    }
}
