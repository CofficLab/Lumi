import Foundation

enum ViewFormatting {
    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func formatDateTime(_ date: Date) -> String {
        dateTimeFormatter.locale = .current
        return dateTimeFormatter.string(from: date)
    }
}
