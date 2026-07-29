import Foundation
import SwiftData

/// SwiftData model for activity heatmap cache
/// Each record represents one day's activity data
@Model
final class ActivityCacheEntry {
    /// Normalized to start of day
    @Attribute(.unique) var date: Date
    var heatmapCount: Int
    var tokenCount: Int
    var createdAt: Date

    init(date: Date, heatmapCount: Int = 0, tokenCount: Int = 0) {
        self.date = Calendar.current.startOfDay(for: date)
        self.heatmapCount = heatmapCount
        self.tokenCount = tokenCount
        self.createdAt = Date()
    }
}
