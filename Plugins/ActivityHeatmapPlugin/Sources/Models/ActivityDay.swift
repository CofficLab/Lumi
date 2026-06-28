import Foundation

/// Single-day activity data point for the heatmap.
struct ActivityDay: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    /// Activity level: 0 = no activity, 1...4 = increasing activity.
    let level: Int
}
