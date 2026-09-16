import LumiUI
import SwiftUI

/// Daily token consumption line chart.
///
/// Mirrors the HTTP log and conversation dashboards so every settings chart in
/// Lumi shares one visual language.
struct ActivityTokenTrendChart: View {
    let days: [ActivityDay]

    var body: some View {
        AppLineChart(
            points: days.map { AppLineChartPoint(date: $0.date, value: Double($0.tokens)) },
            accessibilityLabel: LumiPluginLocalization.string("Daily token consumption chart", bundle: .module),
            valueLabel: { TokenCountFormat.compact(Int($0)) }
        )
    }
}
