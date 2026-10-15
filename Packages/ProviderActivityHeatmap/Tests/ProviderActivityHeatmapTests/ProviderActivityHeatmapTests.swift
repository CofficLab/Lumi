import Foundation
import Testing
@testable import ProviderActivityHeatmap

@Suite("ProviderActivityHeatmap")
struct ProviderActivityHeatmapTests {
    @Test("day counts are non-negative and snapshots are chronological")
    func modelsAreNormalized() {
        let later = ActivityHeatmapDay(date: Date(timeIntervalSince1970: 200), commitCount: 2)
        let earlier = ActivityHeatmapDay(date: Date(timeIntervalSince1970: 100), commitCount: -4)
        let snapshot = ActivityHeatmapSnapshot(
            repositoryPath: "/tmp/repository",
            generatedAt: Date(timeIntervalSince1970: 300),
            days: [later, earlier]
        )

        #expect(earlier.commitCount == 0)
        #expect(snapshot.days.map(\.date) == [earlier.date, later.date])
    }

    // MARK: - ActivityHeatmapDay normalization & identity

    @Test("day clamps negative counts to zero but preserves zero and positive counts")
    func dayClampsNegativeCounts() {
        let zero = ActivityHeatmapDay(date: Date(timeIntervalSince1970: 0), commitCount: 0)
        let positive = ActivityHeatmapDay(date: Date(timeIntervalSince1970: 1), commitCount: 42)
        let negative = ActivityHeatmapDay(date: Date(timeIntervalSince1970: 2), commitCount: -100)
        let large = ActivityHeatmapDay(date: Date(timeIntervalSince1970: 3), commitCount: 1_000_000)

        #expect(zero.commitCount == 0)
        #expect(positive.commitCount == 42)
        #expect(negative.commitCount == 0)
        #expect(large.commitCount == 1_000_000)
    }

    @Test("day identity is its date")
    func dayIdentityIsDate() {
        let date = Date(timeIntervalSince1970: 123_456)
        let day = ActivityHeatmapDay(date: date, commitCount: 5)
        #expect(day.id == date)
    }

    @Test("days are equal when date and count match")
    func dayEquality() {
        let date = Date(timeIntervalSince1970: 100)
        let a = ActivityHeatmapDay(date: date, commitCount: 3)
        let b = ActivityHeatmapDay(date: date, commitCount: 3)
        let c = ActivityHeatmapDay(date: date, commitCount: 4)
        let d = ActivityHeatmapDay(date: Date(timeIntervalSince1970: 101), commitCount: 3)

        #expect(a == b)
        #expect(a != c)
        #expect(a != d)
    }

    @Test("day hashes consistently for equal values")
    func dayHashability() {
        let date = Date(timeIntervalSince1970: 100)
        let a = ActivityHeatmapDay(date: date, commitCount: 3)
        let b = ActivityHeatmapDay(date: date, commitCount: 3)
        var set: Set<ActivityHeatmapDay> = [a]
        set.insert(b)
        #expect(set.count == 1)
    }

    @Test("day encodes and decodes preserving values")
    func dayCodableRoundtrip() throws {
        let date = Date(timeIntervalSince1970: 100)
        let day = ActivityHeatmapDay(date: date, commitCount: 7)
        let data = try JSONEncoder().encode(day)
        let decoded = try JSONDecoder().decode(ActivityHeatmapDay.self, from: data)
        #expect(decoded == day)
        #expect(decoded.commitCount == 7)
    }

    // MARK: - ActivityHeatmapSnapshot

    @Test("snapshot preserves repository path and generated timestamp")
    func snapshotPreservesMetadata() {
        let generated = Date(timeIntervalSince1970: 999)
        let snapshot = ActivityHeatmapSnapshot(
            repositoryPath: "/Users/angel/repos/lumi",
            generatedAt: generated,
            days: []
        )
        #expect(snapshot.repositoryPath == "/Users/angel/repos/lumi")
        #expect(snapshot.generatedAt == generated)
        #expect(snapshot.days.isEmpty)
    }

    @Test("snapshot accepts empty day list without crashing")
    func snapshotHandlesEmptyDays() {
        let snapshot = ActivityHeatmapSnapshot(
            repositoryPath: "/tmp/empty",
            generatedAt: Date(timeIntervalSince1970: 1),
            days: []
        )
        #expect(snapshot.days == [])
    }

    @Test("snapshot sorts already-ordered days without duplicating")
    func snapshotSortIsStableForOrderedInput() {
        let d1 = ActivityHeatmapDay(date: Date(timeIntervalSince1970: 10), commitCount: 1)
        let d2 = ActivityHeatmapDay(date: Date(timeIntervalSince1970: 20), commitCount: 2)
        let d3 = ActivityHeatmapDay(date: Date(timeIntervalSince1970: 30), commitCount: 3)
        let snapshot = ActivityHeatmapSnapshot(
            repositoryPath: "/tmp/repo",
            generatedAt: Date(timeIntervalSince1970: 40),
            days: [d1, d2, d3]
        )
        #expect(snapshot.days.map(\.commitCount) == [1, 2, 3])
    }

    @Test("snapshot equality compares repository, timestamp and days")
    func snapshotEquality() {
        let date = Date(timeIntervalSince1970: 500)
        let days = [ActivityHeatmapDay(date: Date(timeIntervalSince1970: 1), commitCount: 1)]
        let a = ActivityHeatmapSnapshot(repositoryPath: "/r", generatedAt: date, days: days)
        let b = ActivityHeatmapSnapshot(repositoryPath: "/r", generatedAt: date, days: days)
        let c = ActivityHeatmapSnapshot(repositoryPath: "/other", generatedAt: date, days: days)

        #expect(a == b)
        #expect(a != c)
    }

    @Test("snapshot encodes and decodes preserving chronological days")
    func snapshotCodableRoundtrip() throws {
        let days = [
            ActivityHeatmapDay(date: Date(timeIntervalSince1970: 30), commitCount: 3),
            ActivityHeatmapDay(date: Date(timeIntervalSince1970: 10), commitCount: 1),
            ActivityHeatmapDay(date: Date(timeIntervalSince1970: 20), commitCount: 2),
        ]
        let snapshot = ActivityHeatmapSnapshot(
            repositoryPath: "/tmp/repo",
            generatedAt: Date(timeIntervalSince1970: 100),
            days: days
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(ActivityHeatmapSnapshot.self, from: data)

        #expect(decoded == snapshot)
        // Days must remain chronological after decode.
        let dates = decoded.days.map(\.date.timeIntervalSince1970)
        #expect(dates == dates.sorted())
    }

    // MARK: - ActivityHeatmapEvent

    @Test("heatmap events compare by case")
    @MainActor
    func heatmapEventEquality() {
        #expect(ActivityHeatmapEvent.snapshotChanged == .snapshotChanged)
        #expect(ActivityHeatmapEvent.loadingChanged == .loadingChanged)
        #expect(ActivityHeatmapEvent.snapshotChanged != .loadingChanged)
    }
}
