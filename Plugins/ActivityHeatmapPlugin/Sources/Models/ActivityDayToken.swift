import Foundation

/// A single day's total token consumption for the line chart.
public struct ActivityDayToken: Identifiable, Sendable, Equatable {
    public let id: UUID
    /// Calendar date (start of day).
    public let date: Date
    /// Total tokens consumed on this day.
    public let totalTokens: Int

    public init(id: UUID = UUID(), date: Date, totalTokens: Int) {
        self.id = id
        self.date = date
        self.totalTokens = totalTokens
    }
}
