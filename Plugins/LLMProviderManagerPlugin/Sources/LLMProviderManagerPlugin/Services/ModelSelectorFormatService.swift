import Foundation

public enum ModelSelectorFormatService {
    private static let tpsFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 0
        return f
    }()

    private static let tokenFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    public static func tps(_ tps: Double) -> String {
        if let s = tpsFormatter.string(from: NSNumber(value: tps)) {
            return "\(s) tok/s"
        }
        return "\(Int(tps)) tok/s"
    }

    public static func contextSize(_ tokens: Int) -> String {
        let formatted: String
        if let s = tokenFormatter.string(from: NSNumber(value: tokens)) {
            formatted = s
        } else {
            formatted = "\(tokens)"
        }
        return "\(formatted)k ctx"
    }

    public static func tokenCount(_ tokens: Int) -> String {
        if let s = tokenFormatter.string(from: NSNumber(value: tokens)) {
            return s
        }
        return "\(tokens)"
    }

    /// Compact token count for dense UI such as usage cards and chart headers.
    /// The exact comma-separated value should be provided as a tooltip beside it.
    public static func compactTokenCount(_ tokens: Int) -> String {
        let value = Double(tokens)
        let (scaled, suffix): (Double, String) = {
            switch abs(value) {
            case 1_000_000_000...:
                return (value / 1_000_000_000, "B")
            case 1_000_000...:
                return (value / 1_000_000, "M")
            case 1_000...:
                return (value / 1_000, "K")
            default:
                return (value, "")
            }
        }()

        guard !suffix.isEmpty else { return tokenCount(tokens) }
        return String(format: "%.2f%@", scaled, suffix)
    }
}
