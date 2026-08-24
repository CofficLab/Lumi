import Foundation
import Testing
@testable import PluginActivityHeatmap

@Test func activityPeriodHasLegacyRanges() {
    #expect(ActivityHeatmapPeriod.allCases.map(\.rawValue) == [30, 90, 365])
}
