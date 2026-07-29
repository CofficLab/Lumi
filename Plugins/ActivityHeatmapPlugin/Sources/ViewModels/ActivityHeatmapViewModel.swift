import Foundation
import LumiKernel

/// Statistics period options for the heatmap view.
public enum ActivityHeatmapPeriod: Int, CaseIterable, Identifiable, Sendable {
    case days30 = 30
    case days90 = 90
    case year = 365

    public var id: Int { rawValue }

    var localizedTitle: String {
        switch self {
        case .days30:
            LumiPluginLocalization.string("Last 30 days", bundle: .module)
        case .days90:
            LumiPluginLocalization.string("Last 90 days", bundle: .module)
        case .year:
            LumiPluginLocalization.string("Last year", bundle: .module)
        }
    }
}

/// View model that fetches per-day message counts and builds a daily heatmap,
/// plus per-day token counts for a line chart.
///
/// Uses disk cache for historical data (before today) for fast loading.
/// Today's data is always fetched in real-time from MessageManaging.
///
/// Performance notes:
/// - Both data fetches run off the main actor via `nonisolated` requirements
///   on `MessageManaging`, so switching the time range never blocks the UI.
/// - Sequential fetch avoids concurrent access issues with the shared service reference.
/// - `loadGeneration` cancels stale loads: rapidly switching the period won't
///   let an older, slower response overwrite a newer one.
/// - Historical data (before today) is cached on disk for fast subsequent loads.
@MainActor
@Observable
public final class ActivityHeatmapViewModel {
    // MARK: - Dependencies

    private let messageService: (any MessageManaging)?
    private let cache: ActivityHeatmapCache

    // MARK: - State

    private(set) public var heatmapData: [ActivityDay] = []
    private(set) public var tokenData: [ActivityDayToken] = []
    private(set) public var isLoading = false
    private(set) public var hasLoaded = false
    /// The selected period. The owning view drives reloads explicitly
    /// (`onChange` → `load()`), which avoids the double-load that a `didSet`
    /// trigger would cause during initial `.task` seeding.
    public var period: ActivityHeatmapPeriod = .year

    /// Statistics derived from the currently selected period.
    public var statistics: ActivityHeatmapStatistics {
        ActivityHeatmapStatistics(activity: heatmapData, tokens: tokenData)
    }

    /// Bumped on every `load()`; results are only applied if the generation is
    /// still current, so a slow earlier request can't clobber a newer one.
    private var loadGeneration = 0

    // MARK: - Init

    public init(messageService: (any MessageManaging)?, cache: ActivityHeatmapCache? = nil, pluginID: String = "com.coffic.activity-heatmap") {
        self.messageService = messageService
        self.cache = cache ?? ActivityHeatmapCache(
            storageDirectory: nil,
            pluginID: pluginID
        )
    }

    // MARK: - Load

    public func load() async {
        guard let service = messageService else {
            hasLoaded = true
            return
        }

        let generation = { loadGeneration += 1; return loadGeneration }()
        isLoading = true
        defer {
            if isCurrent(generation) { isLoading = false }
            hasLoaded = true
        }

        let days = period.rawValue
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard days > 0,
              let oldestDay = cal.date(byAdding: .day, value: -(days - 1), to: today) else {
            if isCurrent(generation) {
                heatmapData = []
                tokenData = []
            }
            return
        }

        // Generate full date range for the period
        let dateRange = (0..<days).compactMap { cal.date(byAdding: .day, value: $0, to: oldestDay) }

        // Split into historical (before today) and today
        let historicalDates = dateRange.filter { $0 < today }
        let todayDate = today

        // Step 1: Load cached data for historical dates
        let cachedHeatmapCounts = await cache.loadHeatmapCounts(for: historicalDates)
        let cachedTokenCounts = await cache.loadTokenCounts(for: historicalDates)

        // Step 2: Find missing dates that need to be fetched
        let missingHeatmapDates = historicalDates.filter { cachedHeatmapCounts[$0] == nil }
        let missingTokenDates = historicalDates.filter { cachedTokenCounts[$0] == nil }

        // Step 3: Fetch missing data from MessageManaging
        var freshHeatmapCounts: [Date: Int] = [:]
        var freshTokenCounts: [Date: Int] = [:]

        if let firstMissing = missingHeatmapDates.first {
            freshHeatmapCounts = await service.fetchDailyMessageCounts(since: firstMissing)
        }
        if let firstMissing = missingTokenDates.first {
            freshTokenCounts = await service.fetchDailyTokenCounts(since: firstMissing)
        }

        guard isCurrent(generation) else { return }

        // Step 4: Save fresh data to cache (only historical, not today).
        // The aggregate queries omit dates with no records, so explicitly
        // persist those dates as zero; otherwise every subsequent load would
        // treat them as cache misses and rescan the message store.
        let heatmapCountsToCache = Dictionary(uniqueKeysWithValues: missingHeatmapDates.map {
            ($0, freshHeatmapCounts[$0] ?? 0)
        })
        let tokenCountsToCache = Dictionary(uniqueKeysWithValues: missingTokenDates.map {
            ($0, freshTokenCounts[$0] ?? 0)
        })
        await cache.saveCounts(
            heatmapCounts: heatmapCountsToCache,
            tokenCounts: tokenCountsToCache
        )

        // Step 5: Merge cached and fresh data
        var allHeatmapCounts: [Date: Int] = cachedHeatmapCounts
        for (date, count) in freshHeatmapCounts {
            allHeatmapCounts[date] = count
        }

        var allTokenCounts: [Date: Int] = cachedTokenCounts
        for (date, count) in freshTokenCounts {
            allTokenCounts[date] = count
        }

        // Step 6: Fetch today's data in real-time
        let todayHeatmapCounts = await service.fetchDailyMessageCounts(since: todayDate)
        let todayTokenCounts = await service.fetchDailyTokenCounts(since: todayDate)

        guard isCurrent(generation) else { return }

        // Merge today's data
        for (date, count) in todayHeatmapCounts {
            allHeatmapCounts[date] = count
        }
        for (date, count) in todayTokenCounts {
            allTokenCounts[date] = count
        }

        // Step 7: Build final display data
        heatmapData = Self.buildHeatmapData(counts: allHeatmapCounts, oldestDay: oldestDay, days: days)
        tokenData = Self.buildTokenData(tokenCounts: allTokenCounts, oldestDay: oldestDay, days: days)
    }

    private func isCurrent(_ generation: Int) -> Bool {
        generation == loadGeneration
    }

    // MARK: - Heatmap shaping

    /// Builds the calendar of `days` days (`oldestDay` → today) and normalizes
    /// each day's count against the window's max into levels 0–4.
    public nonisolated static func buildHeatmapData(
        counts: [Date: Int],
        oldestDay: Date,
        days: Int
    ) -> [ActivityDay] {
        let cal = Calendar.current
        guard days > 0 else { return [] }

        let calendarDays = (0..<days).compactMap {
            cal.date(byAdding: .day, value: $0, to: oldestDay)
        }

        let windowCounts = calendarDays.compactMap { counts[$0] }
        let maxCount = windowCounts.max() ?? 0
        guard maxCount > 0 else {
            return calendarDays.map { ActivityDay(date: $0, level: 0, messageCount: 0) }
        }

        return calendarDays.map { date in
            let count = counts[date] ?? 0
            let level = min(4, Int(Double(count) / Double(maxCount) * 4.99))
            return ActivityDay(date: date, level: level, messageCount: count)
        }
    }

    // MARK: - Token data shaping

    /// Builds the calendar of `days` days (`oldestDay` → today) with per-day
    /// token totals for the line chart.
    public nonisolated static func buildTokenData(
        tokenCounts: [Date: Int],
        oldestDay: Date,
        days: Int
    ) -> [ActivityDayToken] {
        let cal = Calendar.current
        guard days > 0 else { return [] }

        let calendarDays = (0..<days).compactMap {
            cal.date(byAdding: .day, value: $0, to: oldestDay)
        }

        return calendarDays.map { date in
            ActivityDayToken(date: date, totalTokens: tokenCounts[date] ?? 0)
        }
    }
}

/// Human-readable summary metrics for the selected heatmap window.
public struct ActivityHeatmapStatistics: Sendable, Equatable {
    public let totalMessages: Int
    public let activeDays: Int
    public let averageMessagesPerDay: Double
    public let averageMessagesPerActiveDay: Double
    public let peakMessageDay: ActivityDay?
    public let currentStreak: Int
    public let longestStreak: Int
    public let longestIdleStreak: Int
    public let totalTokens: Int
    public let averageTokensPerDay: Int
    public let peakTokenDay: ActivityDayToken?
    public let averageTokensPerMessage: Double
    public let weekdayTotals: [Int]

    public init(activity: [ActivityDay], tokens: [ActivityDayToken]) {
        let sorted = activity.sorted { $0.date < $1.date }
        totalMessages = sorted.reduce(0) { $0 + $1.messageCount }
        activeDays = sorted.filter { $0.messageCount > 0 }.count
        averageMessagesPerDay = sorted.isEmpty ? 0 : Double(totalMessages) / Double(sorted.count)
        averageMessagesPerActiveDay = activeDays == 0 ? 0 : Double(totalMessages) / Double(activeDays)
        peakMessageDay = sorted.filter { $0.messageCount > 0 }.max { $0.messageCount < $1.messageCount }

        let streaks = Self.streaks(sorted.map { $0.messageCount > 0 })
        longestStreak = streaks.max() ?? 0
        currentStreak = Self.currentStreak(sorted.map { $0.messageCount > 0 })
        longestIdleStreak = Self.streaks(sorted.map { $0.messageCount == 0 }).max() ?? 0

        let tokenValues = tokens.sorted { $0.date < $1.date }
        totalTokens = tokenValues.reduce(0) { $0 + $1.totalTokens }
        averageTokensPerDay = tokenValues.isEmpty ? 0 : totalTokens / tokenValues.count
        peakTokenDay = tokenValues.filter { $0.totalTokens > 0 }.max { $0.totalTokens < $1.totalTokens }
        averageTokensPerMessage = totalMessages == 0 ? 0 : Double(totalTokens) / Double(totalMessages)

        var totals = Array(repeating: 0, count: 7)
        let calendar = Calendar.current
        for day in sorted where day.messageCount > 0 {
            totals[calendar.component(.weekday, from: day.date) - 1] += day.messageCount
        }
        weekdayTotals = totals
    }

    private static func streaks(_ values: [Bool]) -> [Int] {
        var result: [Int] = []
        var current = 0
        for value in values {
            if value { current += 1 } else if current > 0 { result.append(current); current = 0 }
        }
        if current > 0 { result.append(current) }
        return result
    }

    private static func currentStreak(_ values: [Bool]) -> Int {
        var count = 0
        for value in values.reversed() {
            guard value else { break }
            count += 1
        }
        return count
    }
}
