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
}
