import Foundation

extension Int {
    /// 格式化 token 数量为简短显示：1000 → "1K"，1500 → "2K"。
    var formattedTokensShort: String {
        let k = (self + 999) / 1000
        return "\(k)K"
    }

    /// 格式化上下文大小为简短显示：128000 → "128K"，1000000 → "1M"。
    var formattedContextSize: String {
        if self >= 1_000_000 {
            let m = Double(self) / 1_000_000
            if m == m.rounded() { return "\(Int(m))M" }
            return String(format: "%.1fM", m)
        }
        return "\(self / 1000)K"
    }
}
