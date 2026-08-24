import Foundation
import LocalizationKit

enum ViewFormatting {
    static func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = LumiLocalization.preferredLocale()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
