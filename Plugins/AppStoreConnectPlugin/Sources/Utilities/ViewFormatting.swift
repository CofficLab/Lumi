import Foundation
import LumiCoreKit

enum ViewFormatting {
    static func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = LumiPluginLocalization.preferredLocale()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
