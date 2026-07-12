import Testing
import Foundation
@testable import ActivityHeatmapPlugin

@Suite("ActivityHeatmapViewModel")
struct ActivityHeatmapViewModelTests {

    // MARK: - buildHeatmapData (pure, nonisolated)

    @Test("All-empty window yields all level-0 days with correct count")
    func allEmptyWindow() {
        let cal = Calendar.current
        let oldest = cal.startOfDay(for: Date())
        let days = 7

        let result = ActivityHeatmapViewModel.buildHeatmapData(
            counts: [:],
            oldestDay: oldest,
            days: days
        )

        #expect(result.count == days)
        #expect(result.allSatisfy { $0.level == 0 })
    }

    @Test("Max count maps to level 4, zero stays 0, mid values interpolate")
    func levelNormalization() {
        let cal = Calendar.current
        let oldest = cal.startOfDay(for: Date())
        // 4-day window.
        let d0 = oldest
        let d1 = cal.date(byAdding: .day, value: 1, to: oldest)!
        let d2 = cal.date(byAdding: .day, value: 2, to: oldest)!
        let d3 = cal.date(byAdding: .day, value: 3, to: oldest)!

        // max = 100 on d3. 0 → 0, 25 → ~1, 60 → ~2-3, 100 → 4.
        let counts: [Date: Int] = [d0: 0, d1: 25, d2: 60, d3: 100]

        let result = ActivityHeatmapViewModel.buildHeatmapData(
            counts: counts,
            oldestDay: oldest,
            days: 4
        )

        #expect(result.count == 4)
        #expect(result[0].level == 0) // 0/100
        let l1 = result[1].level
        let l2 = result[2].level
        let l3 = result[3].level
        // Monotonic non-decreasing for monotonic input.
        #expect(l1 <= l2)
        #expect(l2 <= l3)
        #expect(l3 == 4) // max always → 4 (100/100 * 4.99 → 4.99 → 4)
        #expect(l1 >= 1) // 25/100 * 4.99 = 1.2475 → 1
    }

    @Test("Counts outside the window are ignored")
    func ignoresOutOfWindowCounts() {
        let cal = Calendar.current
        let oldest = cal.startOfDay(for: Date())
        let days = 3

        // A day before the window and a day after.
        let before = cal.date(byAdding: .day, value: -5, to: oldest)!
        let after = cal.date(byAdding: .day, value: 10, to: oldest)!
        let inWindow = oldest

        let counts: [Date: Int] = [before: 999, after: 999, inWindow: 10]

        let result = ActivityHeatmapViewModel.buildHeatmapData(
            counts: counts,
            oldestDay: oldest,
            days: days
        )

        #expect(result.count == days)
        // Only inWindow has a count; it's the max → level 4.
        let inWindowDay = result.first { $0.date == inWindow }
        #expect(inWindowDay?.level == 4)
        // All other in-window days are level 0.
        #expect(result.filter { $0.date != inWindow }.allSatisfy { $0.level == 0 })
    }

    @Test("days <= 0 yields empty")
    func zeroDays() {
        let result = ActivityHeatmapViewModel.buildHeatmapData(
            counts: [Date(): 5],
            oldestDay: Date(),
            days: 0
        )
        #expect(result.isEmpty)
    }

    @Test("Window spans exactly N consecutive days ending today")
    func consecutiveCalendarDays() {
        let cal = Calendar.current
        // Mirror how `load()` computes the window: oldest = today - (days-1),
        // so the window ends on today.
        let today = cal.startOfDay(for: Date())
        let days = 30
        let oldest = cal.date(byAdding: .day, value: -(days - 1), to: today)!

        let result = ActivityHeatmapViewModel.buildHeatmapData(
            counts: [:],
            oldestDay: oldest,
            days: days
        )

        #expect(result.count == days)
        for (index, day) in result.enumerated() {
            let expected = cal.date(byAdding: .day, value: index, to: oldest)!
            #expect(cal.isDate(day.date, inSameDayAs: expected))
        }
        // First day is the oldest, last day is "today".
        #expect(cal.isDate(result.first!.date, inSameDayAs: oldest))
        #expect(cal.isDateInToday(result.last!.date))
    }

    // MARK: - ActivityDay identity

    @Test("ActivityDay uses its date as stable identity")
    func activityDayIdentity() {
        let date = Calendar.current.startOfDay(for: Date())
        let day = ActivityDay(date: date, level: 2)
        #expect(day.id == date)
    }
}

@Suite("ActivityHeatmapViewModel load()", .serialized)
@MainActor
struct ActivityHeatmapViewModelLoadTests {

    @Test("Nil service marks loaded and stays empty")
    func nilServiceLoadsEmpty() async {
        let vm = ActivityHeatmapViewModel(historyService: nil)
        await vm.load()
        #expect(vm.hasLoaded)
        #expect(vm.heatmapData.isEmpty)
        #expect(vm.isLoading == false)
    }

    @Test("Changing period keeps state consistent")
    func periodChangeConsistent() async {
        let vm = ActivityHeatmapViewModel(historyService: nil)
        vm.period = .days30
        await vm.load()
        #expect(vm.hasLoaded)
        #expect(vm.isLoading == false)
        // Switching to another period on a nil service still yields empty data.
        vm.period = .days90
        await vm.load()
        #expect(vm.heatmapData.isEmpty)
    }
}
