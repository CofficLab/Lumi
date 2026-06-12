import Foundation

public enum ModelSelectorFormatService {
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

    public static func durationMilliseconds(_ milliseconds: Double) -> String {
        if milliseconds >= 1000 {
            return String(format: "%.1fs", milliseconds / 1000.0)
        } else {
            return String(format: "%.0fms", milliseconds)
        }
    }

    public static func tps(_ tps: Double) -> String {
        if tps >= 100 {
            return String(format: "%.0f t/s", tps)
        } else if tps >= 10 {
            return String(format: "%.1f t/s", tps)
        } else {
            return String(format: "%.2f t/s", tps)
        }
    }
}
