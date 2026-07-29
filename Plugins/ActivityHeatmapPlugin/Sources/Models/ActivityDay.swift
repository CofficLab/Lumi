import Foundation

/// A single day's activity level for the heatmap.
public struct ActivityDay: Identifiable, Sendable, Equatable {
    public let id: Date
    /// Calendar date (start of day) for this activity entry.
    public let date: Date
    /// Intensity level 0–4, where 0 = no activity and 4 = highest activity.
    public let level: Int
    /// Raw number of messages for this day.
    public let messageCount: Int

    public init(date: Date, level: Int, messageCount: Int = 0) {
        self.id = date
        self.date = date
        self.level = level
        self.messageCount = messageCount
    }
}
