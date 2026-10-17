import Foundation
import LumiUI
import ProviderMessage

/// One day's message count, already mapped onto a display level.
///
/// Levels are relative to the busiest day inside the window, so the strip
/// stays readable for both light and heavy users instead of relying on fixed
/// thresholds that only suit one of them.
struct EmptyStateActivityDay: Equatable, Sendable {
    let date: Date
    let count: Int
    /// `0` for a day with no messages, otherwise `1...4`.
    let level: Int

    var accessibilityLabel: String { "\(date.formatted(date: .long, time: .omitted)): \(count)" }
}

/// One day's token consumption, kept separate from ``EmptyStateActivityDay``
/// because the token series has its own emptiness rule: a day can have messages
/// but zero tokens, so folding it into the message day would silently reuse a
/// level that was derived from an unrelated scale.
struct EmptyStateTokenDay: Equatable, Sendable {
    let date: Date
    let count: Int

    var accessibilityLabel: String { "\(date.formatted(date: .long, time: .omitted)): \(count)" }
}

/// Fills the empty state with a quiet 30-day activity strip.
///
/// This view model owns the only question the strip asks: how many messages
/// were sent on each of the last 30 calendar days. It reads cross-conversation
/// statistics from ``MessageManaging`` so the strip reflects the user's actual
/// history rather than the empty conversation being displayed.
@MainActor
@Observable
final class EmptyStateActivityViewModel {
    /// How many trailing calendar days the strip covers.
    ///
    /// `nonisolated` because it is an immutable literal that the pure bucketing
    /// helpers (`makeDays` / `makeTokenDays`) also need to size their output.
    nonisolated static let windowDayCount = 30
    /// Four active buckets plus the empty one, matching `AppActivityHeatmap`'s
    /// default level count.
    private static let levelCount = 5

    private let messages: (any MessageManaging)?
    private let calendar: Calendar
    /// Guards against a slow load from an earlier window overwriting a newer
    /// result when the plugin reboots or the conversation selection changes.
    private var loadGeneration = 0

    private(set) var days: [EmptyStateActivityDay] = []
    private(set) var isLoading = false

    /// Total messages inside the window. `nil` until the first load resolves.
    private(set) var totalMessages: Int?

    /// Daily token consumption over the same window as ``days``.
    private(set) var tokenDays: [EmptyStateTokenDay] = []

    /// Tokens consumed inside the window, or `nil` before the first load.
    private(set) var totalTokens: Int?

    /// Zero tokens means the trend line would be a flat axis with nothing to
    /// say, so the chart is omitted rather than drawn empty.
    var hasTokenActivity: Bool {
        totalTokens.map { $0 > 0 } ?? false
    }

    /// Oldest and newest visible day, or `nil` before the first load.
    var visibleRange: ClosedRange<Date>? {
        guard let first = days.first?.date, let last = days.last?.date else { return nil }
        return first...last
    }

    /// No activity means there is nothing worth showing: a grid of 30 empty
    /// cells reads as "you have never used this app", which is both ugly and
    /// discouraging. The strip is omitted instead.
    var hasActivity: Bool {
        totalMessages.map { $0 > 0 } ?? false
    }

    /// - Parameters:
    ///   - messages: Source of cross-conversation daily counts.
    ///   - calendar: Calendar used to normalize dates into day buckets.
    ///   - seededDays: Precomputed message window for previews and tests. When
    ///     nil the model loads through ``loadIfNeeded(force:)`` as usual.
    ///   - seededTokenDays: Precomputed token window. Separate from
    ///     `seededDays` because the two series scale independently — deriving
    ///     one from the other would make previews and the hidden-state checks
    ///     describe data that the real load path never produces.
    init(
        messages: (any MessageManaging)?,
        calendar: Calendar = .current,
        seededDays: [EmptyStateActivityDay]? = nil,
        seededTokenDays: [EmptyStateTokenDay]? = nil
    ) {
        self.messages = messages
        self.calendar = calendar
        if let seededDays {
            days = seededDays
            totalMessages = seededDays.reduce(0) { $0 + $1.count }
        }
        if let seededTokenDays {
            tokenDays = seededTokenDays
            totalTokens = seededTokenDays.reduce(0) { $0 + $1.count }
        }
    }

    /// Loads the window, unless it is already loaded for the same end day.
    ///
    /// The strip is pure history, so repeated appearances of the empty state
    /// should not re-query the database unless the calendar window moved.
    func loadIfNeeded(force: Bool = false) async {
        guard let messages else { return }

        let today = calendar.startOfDay(for: .now)
        if !force, let visibleRange, visibleRange.upperBound == today, totalMessages != nil {
            return
        }

        loadGeneration &+= 1
        let generation = loadGeneration
        isLoading = true
        defer { isLoading = false }

        let startDate = calendar.date(
            byAdding: .day,
            value: -(Self.windowDayCount - 1),
            to: today
        ) ?? today
        let counts = await messages.dailyMessageCountsAsync(since: startDate)
        let tokens = await messages.dailyTokenCountsAsync(since: startDate)
        guard !Task.isCancelled, generation == loadGeneration else { return }

        days = Self.makeDays(counts: counts, startDate: startDate, endDate: today, calendar: calendar)
        totalMessages = days.reduce(0) { $0 + $1.count }
        tokenDays = Self.makeTokenDays(
            counts: tokens,
            startDate: startDate,
            endDate: today,
            calendar: calendar
        )
        totalTokens = tokenDays.reduce(0) { $0 + $1.count }
    }

    /// Builds one entry per calendar day in the window, including days with no
    /// messages, and assigns levels relative to the busiest day.
    ///
    /// Split out from ``loadIfNeeded(force:)`` so the level mapping is testable
    /// without a live message store.
    static func makeDays(
        counts: [Date: Int],
        startDate: Date,
        endDate: Date,
        calendar: Calendar
    ) -> [EmptyStateActivityDay] {
        let normalizedCounts = Dictionary(
            counts.map { (calendar.startOfDay(for: $0.key), $0.value) },
            uniquingKeysWith: { current, latest in max(current, latest) }
        )

        var entries: [EmptyStateActivityDay] = []
        entries.reserveCapacity(windowDayCount)

        var cursor = startDate
        while cursor <= endDate {
            let count = normalizedCounts[cursor] ?? 0
            entries.append(EmptyStateActivityDay(date: cursor, count: count, level: 0))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return levels(entries: entries, levelCount: levelCount)
    }

    /// Builds one token entry per calendar day in the window, including days
    /// with no consumption, so the trend line keeps a continuous x-axis.
    ///
    /// - Important: `nonisolated` because it is pure date bucketing over plain
    ///   values — it touches no view-model state, so isolating it would only
    ///   force callers (previews, tests) onto the main actor for no reason.
    nonisolated static func makeTokenDays(
        counts: [Date: Int],
        startDate: Date,
        endDate: Date,
        calendar: Calendar
    ) -> [EmptyStateTokenDay] {
        let normalizedCounts = Dictionary(
            counts.map { (calendar.startOfDay(for: $0.key), $0.value) },
            uniquingKeysWith: { current, latest in max(current, latest) }
        )

        var entries: [EmptyStateTokenDay] = []
        entries.reserveCapacity(windowDayCount)

        var cursor = startDate
        while cursor <= endDate {
            entries.append(EmptyStateTokenDay(date: cursor, count: normalizedCounts[cursor] ?? 0))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return entries
    }

    /// Distributes counts into buckets so the busiest day lands on the top
    /// level and quiet days stay visible near the bottom.
    private static func levels(entries: [EmptyStateActivityDay], levelCount: Int) -> [EmptyStateActivityDay] {
        let peak = entries.map(\.count).max() ?? 0
        guard peak > 0 else { return entries }

        let activeLevels = levelCount - 1
        return entries.map { entry in
            guard entry.count > 0 else { return entry }
            // Ceiling division keeps a day with one message at level 1 rather
            // than rounding it down to the empty level.
            let ratio = Double(entry.count) / Double(peak)
            let level = min(max(Int(ceil(ratio * Double(activeLevels))), 1), activeLevels)
            return EmptyStateActivityDay(date: entry.date, count: entry.count, level: level)
        }
    }
}
