import Foundation
import ProviderActivityHeatmap
import Testing
@testable import PluginActivityHeatmap

/// 回归 #506：summary 必须与 52 周网格共用同一日期窗口，
/// 不能把 12 个月加载窗口里、网格之外的提交计入总数/活跃天数。
@Suite("Git activity summary window")
struct GitActivityHeatmapSummaryTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 1
        return calendar
    }()

    // 固定 now = 2025-06-18（周三）。当前周周日 = 2025-06-15，
    // 网格起点 = 2024-06-23（周日），网格末格 = 2025-06-21（周六），
    // 窗口右开边界 = 2025-06-22。这些日期独立于被测 helper 推导，作为 oracle。
    private var now: Date { day(2025, 6, 18) }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        components.timeZone = TimeZone(identifier: "UTC")
        return calendar.date(from: components)!
    }

    private func snapshot(_ days: [(Date, Int)]) -> ActivityHeatmapSnapshot {
        ActivityHeatmapSnapshot(
            repositoryPath: "/tmp/repo",
            generatedAt: now,
            days: days.map { ActivityHeatmapDay(date: $0.0, commitCount: $0.1) }
        )
    }

    @Test("counts only the visible 52-week window, not the wider 12-month load range")
    func outOfWindowDayIsNotCounted() {
        // 2024-06-22 在 12 个月加载窗口内（cutoff = 2024-06-18），但早于网格起点 2024-06-23。
        let beforeGrid = day(2024, 6, 22)
        let result = GitActivityHeatmapProjectSection.visibleSummary(
            snapshot: snapshot([(beforeGrid, 5), (now, 1)]),
            calendar: calendar,
            weekCount: 52,
            now: now
        )
        #expect(result.total == 1)
        #expect(result.activeDays == 1)
    }

    @Test("counts every visible day inclusively from grid start through the last cell")
    func inWindowDaysAreCounted() {
        let gridStart = day(2024, 6, 23)
        let lastVisible = day(2025, 6, 21)
        let zeroDay = day(2025, 6, 17)
        let result = GitActivityHeatmapProjectSection.visibleSummary(
            snapshot: snapshot([(gridStart, 2), (now, 3), (lastVisible, 1), (zeroDay, 0)]),
            calendar: calendar,
            weekCount: 52,
            now: now
        )
        #expect(result.total == 6)
        #expect(result.activeDays == 3)
    }

    @Test("excludes the day at the exclusive right edge of the grid window")
    func gridEndIsExclusive() {
        let lastVisible = day(2025, 6, 21)
        let gridEnd = day(2025, 6, 22)
        let result = GitActivityHeatmapProjectSection.visibleSummary(
            snapshot: snapshot([(lastVisible, 1), (gridEnd, 4)]),
            calendar: calendar,
            weekCount: 52,
            now: now
        )
        #expect(result.total == 1)
        #expect(result.activeDays == 1)
    }
}