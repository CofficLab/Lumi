import Foundation

/// Token 数与速率的紧凑格式化, 供模型卡片等处复用。
public enum TokenCountFormat {
    /// 速率(t/s): 大值低精度, 小值高精度。
    public static func tps(_ tps: Double) -> String {
        if tps >= 100 {
            return String(format: "%.0f t/s", tps)
        }
        if tps >= 10 {
            return String(format: "%.1f t/s", tps)
        }
        return String(format: "%.2f t/s", tps)
    }

    /// 将 token 数格式化为上下文窗口大小的简短表示。
    public static func contextSize(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            let value = Double(tokens) / 1_000_000.0
            return value == floor(value) ? "\(Int(value))M" : String(format: "%.1fM", value)
        } else if tokens >= 1_000 {
            let value = Double(tokens) / 1_000.0
            return value == floor(value) ? "\(Int(value))K" : String(format: "%.0fK", value)
        } else {
            return "\(tokens)"
        }
    }

    /// 将 token 用量格式化为紧凑表示, 用于每日用量摘要。
    /// 与 `contextSize` 不同: K 档保留一位小数(1.2K), 因为用量场景下小数更有意义。
    public static func tokenCount(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            let value = Double(tokens) / 1_000_000.0
            return value == floor(value) ? "\(Int(value))M" : String(format: "%.1fM", value)
        } else if tokens >= 1_000 {
            let value = Double(tokens) / 1_000.0
            return value == floor(value) ? "\(Int(value))K" : String(format: "%.1fK", value)
        } else {
            return "\(tokens)"
        }
    }
}
