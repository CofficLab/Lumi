import Foundation
import Testing
@testable import PluginMessageListEmpty

/// Covers the message-side window bucketing and level mapping.
///
/// `EmptyStateTokenTrendTests` covers the token series, which shares the window
/// shape but has its own emptiness rule. The message series additionally runs
/// every entry through the level mapping, so it needs its own tests: a silent
/// regression there would show up only as a heatmap that is uniformly too faint
/// or too dark to read, which no other test in the package would catch.

@MainActor
@Suite("Empty state activity window")
struct EmptyStateActivityWindowTests {
    private let calendar = Calendar(identifier: .gregorian)

    /// Non-throwing on purpose: `#expect` evaluates its operands inside a
    /// non-throwing autoclosure, so a throwing helper cannot be called there.
    private func day(_ offsetFromToday: Int) -> Date {
        let today = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .day, value: offsetFromToday, to: today)!
    }

    @Test("the window covers every calendar day including idle ones")
    func windowCoversIdleDays() {
        let start = day(-2)
        let end = day(0)

        let days = EmptyStateActivityViewModel.makeDays(
            counts: [start: 2],
            startDate: start,
            endDate: end,
            calendar: calendar
        )

        #expect(days.count == 3)
        #expect(days.map(\.date) == [start, day(-1), end])
        #expect(days.map(\.count) == [2, 0, 0])
        // Days without messages must stay on the empty level even though a
        // sibling day is active, so idle cells never inherit the peak's shade.
        #expect(days.map(\.level) == [4, 0, 0])
    }

    @Test("timestamps inside one day collapse into a single bucket")
    func timestampsNormalizeIntoDayBuckets() throws {
        let start = day(-1)
        let midday = try #require(calendar.date(byAdding: .hour, value: 12, to: start))
        let evening = try #require(calendar.date(byAdding: .hour, value: 20, to: start))

        let days = EmptyStateActivityViewModel.makeDays(
            counts: [midday: 3, evening: 9],
            startDate: start,
            endDate: day(0),
            calendar: calendar
        )

        // The provider already returns per-day totals, so the merge must take the
        // larger value rather than summing — summing would double count.
        #expect(days.map(\.count) == [9, 0])
    }

    /// The same merge rule, but with the larger count arriving **first**.
    ///
    /// Dictionary iteration order is not guaranteed, so a merge that only works
    /// when the bigger count happens to be visited last is correct by luck.
    /// This case pins the rule independently of ordering.
    @Test("a same-day merge keeps the larger count regardless of arrival order")
    func sameDayMergeKeepsLargerCountInEitherOrder() throws {
        let start = day(-1)
        let midday = try #require(calendar.date(byAdding: .hour, value: 12, to: start))
        let evening = try #require(calendar.date(byAdding: .hour, value: 20, to: start))

        let biggerFirst = EmptyStateActivityViewModel.makeDays(
            counts: [midday: 9, evening: 3],
            startDate: start,
            endDate: day(0),
            calendar: calendar
        )
        let biggerLast = EmptyStateActivityViewModel.makeDays(
            counts: [midday: 3, evening: 9],
            startDate: start,
            endDate: day(0),
            calendar: calendar
        )

        #expect(biggerFirst.map(\.count) == [9, 0])
        #expect(biggerLast.map(\.count) == [9, 0])
        // Summing instead of max-ing would surface as 12.
        #expect(biggerFirst.map(\.count) != [12, 0])
    }

    /// Levels are relative to the busiest day in the window, not fixed
    /// thresholds. That is what keeps the strip readable for a user who sent
    /// three messages this month as well as for one who sent three thousand.
    @Test("levels are normalized against the busiest day in the window")
    func levelsNormalizeAgainstPeak() {
        let start = day(-2)
        let end = day(0)

        let days = EmptyStateActivityViewModel.makeDays(
            counts: [start: 100, day(-1): 50, end: 25],
            startDate: start,
            endDate: end,
            calendar: calendar
        )

        // Four active buckets over a peak of 100: 100→4, 50→2, 25→1.
        #expect(days.map(\.level) == [4, 2, 1])
    }

    @Test("a quiet day next to a busy one stays on the lowest active level")
    func quietDayDoesNotRoundDownToEmpty() {
        let start = day(-2)
        let end = day(0)

        let days = EmptyStateActivityViewModel.makeDays(
            counts: [start: 100, end: 1],
            startDate: start,
            endDate: end,
            calendar: calendar
        )

        // Ceiling division matters here: 1/100 of the peak rounds down to the
        // empty level under truncation, which would render a day that genuinely
        // had a message as an empty cell.
        #expect(days.map(\.count) == [100, 0, 1])
        #expect(days.map(\.level) == [4, 0, 1])
    }

    @Test("the only active day is the peak and lands on the top level")
    func loneActiveDayIsThePeak() {
        let start = day(-1)
        let end = day(0)

        let days = EmptyStateActivityViewModel.makeDays(
            counts: [end: 1],
            startDate: start,
            endDate: end,
            calendar: calendar
        )

        // Levels are relative to the window, so a single active day is its own
        // peak no matter how small the count is.
        #expect(days.map(\.count) == [0, 1])
        #expect(days.map(\.level) == [0, 4])
    }

    @Test("an all-zero window stays entirely on the empty level")
    func allZeroWindowStaysEmpty() {
        let start = day(-1)
        let end = day(0)

        let days = EmptyStateActivityViewModel.makeDays(
            counts: [:],
            startDate: start,
            endDate: end,
            calendar: calendar
        )

        #expect(days.map(\.count) == [0, 0])
        #expect(days.map(\.level) == [0, 0])
    }

    @Test("a window ending before it starts produces no entries")
    func invertedWindowIsEmpty() {
        let days = EmptyStateActivityViewModel.makeDays(
            counts: [:],
            startDate: day(0),
            endDate: day(-1),
            calendar: calendar
        )

        #expect(days.isEmpty)
    }

    @Test("the visible range spans the first and last day of the window")
    func visibleRangeCoversTheWindow() throws {
        let start = day(-2)
        let end = day(0)

        let model = EmptyStateActivityViewModel(
            messages: nil,
            calendar: calendar,
            seededDays: EmptyStateActivityViewModel.makeDays(
                counts: [day(-1): 3],
                startDate: start,
                endDate: end,
                calendar: calendar
            )
        )

        let range = try #require(model.visibleRange)
        #expect(range.lowerBound == start)
        #expect(range.upperBound == end)
        #expect(model.totalMessages == 3)
        #expect(model.hasActivity)
    }

    @Test("a seeded all-zero window hides the strip instead of drawing an empty grid")
    func seededZeroWindowHidesStrip() {
        let model = EmptyStateActivityViewModel(
            messages: nil,
            calendar: calendar,
            seededDays: EmptyStateActivityViewModel.makeDays(
                counts: [:],
                startDate: day(-1),
                endDate: day(0),
                calendar: calendar
            )
        )

        #expect(model.totalMessages == 0)
        #expect(model.hasActivity == false)
    }
}
