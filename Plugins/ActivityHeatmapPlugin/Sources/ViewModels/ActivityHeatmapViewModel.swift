import Foundation
import LumiCoreKit

/// Statistics period options for the heatmap view.
enum ActivityHeatmapPeriod: Int, CaseIterable, Identifiable {
    case days30 = 30
    case days90 = 90
    case year = 365

    var id: Int { rawValue }

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

/// View model that fetches per-day message counts and builds a daily heatmap.
///
/// Performance notes:
/// - The data fetch (`fetchDailyMessageCounts(since:)`) runs **off the main
///   actor** (it is a `nonisolated` requirement on `HistoryQueryService`), so
///   switching the time range never blocks the UI.
/// - Previously this view loaded *every* message row (paginated, with full
///   previews / thinking / token lookups done on the main actor) and only moved
///   the final aggregation off-thread. Now the whole pipeline is O(days) of CPU
///   on the main thread plus a single windowed, timestamp-only query in the
///   background.
/// - `loadGeneration` cancels stale loads: rapidly switching the period won't
///   let an older, slower response overwrite a newer one.
@MainActor
@Observable
final class ActivityHeatmapViewModel {
    // MARK: - Dependencies

    private let historyService: (any HistoryQueryService)?

    // MARK: - State

    private(set) var heatmapData: [ActivityDay] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    /// The selected period. The owning view drives reloads explicitly
    /// (`onChange` → `load()`), which avoids the double-load that a `didSet`
    /// trigger would cause during initial `.task` seeding.
    var period: ActivityHeatmapPeriod = .year

    /// Bumped on every `load()`; results are only applied if the generation is
    /// still current, so a slow earlier request can't clobber a newer one.
    private var loadGeneration = 0

    // MARK: - Init

    init(historyService: (any HistoryQueryService)?) {
        self.historyService = historyService
    }

    // MARK: - Load

    func load() async {
        guard let service = historyService else {
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
        // First day of the window (inclusive). Guarded by `days > 0`.
        guard days > 0,
              let oldestDay = cal.date(byAdding: .day, value: -(days - 1), to: today) else {
            if isCurrent(generation) { heatmapData = [] }
            return
        }

        // Off-main-actor fetch: a single windowed, timestamp-only query.
        let counts = await service.fetchDailyMessageCounts(since: oldestDay)
        guard isCurrent(generation) else { return }

        // Cheap O(days) shaping on the main thread.
        heatmapData = Self.buildHeatmapData(counts: counts, oldestDay: oldestDay, days: days)
    }

    private func isCurrent(_ generation: Int) -> Bool {
        generation == loadGeneration
    }

    // MARK: - Heatmap shaping

    /// Builds the calendar of `days` days (`oldestDay` → today) and normalizes
    /// each day's count against the window's max into levels 0–4.
    /// `nonisolated static` so it can be unit-tested without the main actor.
    nonisolated static func buildHeatmapData(
        counts: [Date: Int],
        oldestDay: Date,
        days: Int
    ) -> [ActivityDay] {
        let cal = Calendar.current
        guard days > 0 else { return [] }

        let calendarDays = (0..<days).compactMap {
            cal.date(byAdding: .day, value: $0, to: oldestDay)
        }

        // Normalize against the window's own max only. Counts outside the
        // window (which the query normally excludes) must not skew the scale.
        let windowCounts = calendarDays.compactMap { counts[$0] }
        let maxCount = windowCounts.max() ?? 0
        guard maxCount > 0 else {
            return calendarDays.map { ActivityDay(date: $0, level: 0) }
        }

        return calendarDays.map { date in
            let count = counts[date] ?? 0
            let level = min(4, Int(Double(count) / Double(maxCount) * 4.99))
            return ActivityDay(date: date, level: level)
        }
    }
}
