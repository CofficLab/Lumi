import Foundation

extension Int {
    /// 格式化 token 数量为简短显示：1000 → "1K"，1500 → "2K"（向上取整）
    var formattedTokensShort: String {
        let k = (self + 999) / 1000
        return "\(k)K"
    }

    /// 格式化上下文大小为简短显示：128000 → "128K"，1000000 → "1M"
    var formattedContextSize: String {
        if self >= 1_000_000 {
            let m = Double(self) / 1_000_000
            if m == m.rounded() {
                return "\(Int(m))M"
            }
            return String(format: "%.1fM", m)
        }
        let k = self / 1000
        return "\(k)K"
    }

    /// 格式化 token 数量为详情显示：128000 → "128K tokens"，1500000 → "1.5M tokens"
    var formattedContextSizeDetail: String {
        if self >= 1_000_000 {
            let m = Double(self) / 1_000_000
            if m == m.rounded() {
                return "\(Int(m))M tokens"
            }
            return String(format: "%.1fM tokens", m)
        }
        let k = self / 1000
        return "\(k)K tokens"
    }
}
