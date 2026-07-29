import Foundation

/// A single day's total token consumption for the line chart.
public struct ActivityDayToken: Identifiable, Sendable, Equatable {
    public let id: Date
    /// Calendar date (start of day).
    public let date: Date
    /// Total tokens consumed on this day.
    public let totalTokens: Int

    public init(date: Date, totalTokens: Int) {
        self.id = date
        self.date = date
        self.totalTokens = totalTokens
    }
}
