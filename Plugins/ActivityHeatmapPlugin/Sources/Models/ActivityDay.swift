import Foundation

/// A single day's activity level for the heatmap.
public struct ActivityDay: Identifiable, Sendable, Equatable {
    public let id: UUID
    /// Calendar date (start of day) for this activity entry.
    public let date: Date
    /// Intensity level 0–4, where 0 = no activity and 4 = highest activity.
    public let level: Int

    public init(id: UUID = UUID(), date: Date, level: Int) {
        self.id = id
        self.date = date
        self.level = level
    }
}
