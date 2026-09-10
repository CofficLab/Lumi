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
}
