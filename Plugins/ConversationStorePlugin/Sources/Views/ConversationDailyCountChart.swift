import LumiUI
import SwiftUI

struct ConversationDailyCountChart: View {
    let series: ConversationDailyCountSeries

    var body: some View {
        AppLineChart(
            points: series.points.map { AppLineChartPoint(date: $0.day, value: Double($0.count)) },
            accessibilityLabel: "Daily conversation count chart",
            valueLabel: { $0.formatted(.number) }
        )
    }
}
