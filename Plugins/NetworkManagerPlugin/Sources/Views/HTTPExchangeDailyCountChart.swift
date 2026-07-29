import LumiUI
import SwiftUI

struct HTTPExchangeDailyCountChart: View {
    let series: HTTPExchangeDailyCountSeries

    var body: some View {
        AppLineChart(
            points: series.points.map { AppLineChartPoint(date: $0.day, value: Double($0.count)) },
            accessibilityLabel: "Daily HTTP request count chart",
            valueLabel: { $0.formatted(.number) }
        )
        .accessibilityValue("Peak (series.peakCount), total (series.totalCount)")
    }
}
