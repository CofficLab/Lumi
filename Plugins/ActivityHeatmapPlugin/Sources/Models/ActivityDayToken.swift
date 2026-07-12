import Foundation

/// Single-day token usage data point for the line chart.
struct ActivityDayToken: Identifiable, Hashable {
    /// Stable per-day identity: the day's date.
    var id: Date { date }
    let date: Date
    /// Total tokens consumed on this day.
    let totalTokens: Int
}