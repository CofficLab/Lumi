import Foundation

enum ModelSelectorFormatService {
    static func tps(_ tps: Double) -> String {
        if tps >= 100 {
            return String(format: "%.0f t/s", tps)
        }
        if tps >= 10 {
            return String(format: "%.1f t/s", tps)
        }
        return String(format: "%.2f t/s", tps)
    }

    /// 将 token 数格式化为上下文窗口大小的简短表示
    static func contextSize(_ tokens: Int) -> String {
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
}
