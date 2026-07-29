import LumiUI
import SwiftUI

struct AgentTurnDailyCountPoint: Equatable, Identifiable, Sendable {
    let day: Date
    let count: Int

    var id: Date { day }
}

struct AgentTurnDailyCountSeries: Equatable, Sendable {
    let points: [AgentTurnDailyCountPoint]

    var peakCount: Int {
        points.map(\.count).max() ?? 0
    }
}

struct AgentTurnDailyCountChart: View {
    let series: AgentTurnDailyCountSeries

    var body: some View {
        AppLineChart(
            points: series.points.map { AppLineChartPoint(date: $0.day, value: Double($0.count)) },
            accessibilityLabel: "Daily sent request count chart",
            valueLabel: { $0.formatted(.number) }
        )
    }
}
