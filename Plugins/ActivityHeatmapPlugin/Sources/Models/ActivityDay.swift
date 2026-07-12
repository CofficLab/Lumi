import Foundation

/// Single-day activity data point for the heatmap.
struct ActivityDay: Identifiable, Hashable {
    /// Stable per-day identity: the day's date. Using the date (instead of a
    /// fresh `UUID`) lets SwiftUI diff cells across reloads and reuse views when
    /// switching the time range, instead of rebuilding all 30/90/365 cells.
    var id: Date { date }
    let date: Date
    /// Activity level: 0 = no activity, 1...4 = increasing activity.
    let level: Int
}
