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

/// 回归 #504：日期分桶与写入时区绑定，切换时区后旧缓存整体失效。
@Test func activityCacheIgnoresCountsSavedUnderDifferentTimeZone() async throws {
    final class TimeZoneBox: @unchecked Sendable {
        var identifier = "America/Los_Angeles"
    }
    let box = TimeZoneBox()
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let date = Calendar.current.startOfDay(for: Date())
    let cache = ActivityHeatmapCache(directory: directory) {
        TimeZone(identifier: box.identifier)!
    }
    await cache.save([date: ActivityHeatmapCache.Counts(messages: 3, tokens: 42)])

    // 重启后时区已切换：旧时区的分桶必须作废，不得命中。
    box.identifier = "Asia/Shanghai"
    let reloaded = ActivityHeatmapCache(directory: directory) {
        TimeZone(identifier: box.identifier)!
    }
    let counts = await reloaded.counts(for: [date])
    #expect(counts.isEmpty)
}

/// 回归 #504：时区切换后的重查结果按新时区重写缓存，后续重启正常命中。
@Test func activityCacheRewritesCountsUnderNewTimeZoneAfterSwitch() async throws {
    final class TimeZoneBox: @unchecked Sendable {
        var identifier = "America/Los_Angeles"
    }
    let box = TimeZoneBox()
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let date = Calendar.current.startOfDay(for: Date())
    let cache = ActivityHeatmapCache(directory: directory) {
        TimeZone(identifier: box.identifier)!
    }
    await cache.save([date: ActivityHeatmapCache.Counts(messages: 1, tokens: 2)])

    box.identifier = "Asia/Shanghai"
    #expect(await cache.counts(for: [date]).isEmpty)
    let rewritten = ActivityHeatmapCache.Counts(messages: 5, tokens: 50)
    await cache.save([date: rewritten])

    let reloaded = ActivityHeatmapCache(directory: directory) {
        TimeZone(identifier: box.identifier)!
    }
    #expect(await reloaded.counts(for: [date])[date] == rewritten)
}
