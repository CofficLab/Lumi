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
}
