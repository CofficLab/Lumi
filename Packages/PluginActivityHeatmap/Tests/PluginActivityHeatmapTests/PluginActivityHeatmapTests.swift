import Foundation
import Testing
@testable import PluginActivityHeatmap

@Test func activityPeriodHasLegacyRanges() {
    #expect(ActivityHeatmapPeriod.allCases.map(\.rawValue) == [30, 90, 365])
}

@Test func activityCachePersistsHistoricalCounts() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let date = Calendar.current.startOfDay(for: Date())
    let expected = ActivityHeatmapCache.Counts(messages: 3, tokens: 42)
    let cache = ActivityHeatmapCache(directory: directory)
    await cache.save([date: expected])
    let reloaded = ActivityHeatmapCache(directory: directory)
    #expect(await reloaded.counts(for: [date])[date] == expected)
}
