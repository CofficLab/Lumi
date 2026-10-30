import LumiUI
import ProviderConversation
import SwiftUI

/// 每日对话数量折线图。
///
/// 数据模型来自 `ProviderConversation`（跨插件共享），这里只做图表适配。
struct ConversationStatsChart: View {
    let series: ConversationDailyCountSeries

    var body: some View {
        AppLineChart(
            points: series.points.map {
                AppLineChartPoint(date: $0.day, value: Double($0.count))
            },
            accessibilityLabel: "每日对话数量",
            valueLabel: { $0.formatted(.number) }
        )
    }
}
