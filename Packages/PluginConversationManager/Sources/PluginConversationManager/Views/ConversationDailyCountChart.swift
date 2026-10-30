import LumiUI
import ProviderConversation
import SwiftUI

/// 每日对话计数折线图。
///
/// 数据模型来自 `ProviderConversation`（跨插件共享），这里只做图表适配。
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
